param([string]$CleanName='clean-email-v030-20261020',[string]$RunSuffix='02')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$delivery=Join-Path $project 'deliverables\v0.3.0'
$baseline='b4f7aa6edea3bcc90d563015252c4e1fcd900649'
if($RunSuffix -notmatch '^\d{2}$'){throw 'Use a two-digit local review run suffix'}
function Get-CanonicalHash([string]$Path){
  $bytes=[IO.File]::ReadAllBytes($Path)
  if(-not $bytes.Contains([byte]0)){
    try{$decoded=[Text.UTF8Encoding]::new($false,$true).GetString($bytes);$bytes=[Text.UTF8Encoding]::new($false).GetBytes($decoded.Replace("`r`n","`n"))}catch [Text.DecoderFallbackException]{}
  }
  return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}
$clean=Join-Path $project ('.local\'+$CleanName)
if($CleanName -notmatch '^clean-[a-z0-9-]+$' -or -not(Test-Path -LiteralPath $clean)){throw 'Verified clean checkout is required'}
Push-Location -LiteralPath $project
try{
  $appInputs=@(Get-ChildItem lib,android\app\src -Recurse -File)+@(Get-Item pubspec.yaml,pubspec.lock,android\app\build.gradle.kts,android\build.gradle.kts,android\settings.gradle.kts,android\gradle.properties,android\gradle\wrapper\gradle-wrapper.properties)
  $verified=foreach($file in $appInputs){
    $relative=[IO.Path]::GetRelativePath($project,$file.FullName).Replace('\','/')
    $peer=Join-Path $clean $relative
    $hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    if(-not(Test-Path -LiteralPath $peer) -or (Get-FileHash -LiteralPath $peer -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash){throw "App input differs from verified APK: $relative"}
    [PSCustomObject]@{path=$relative;sha256=$hash;generated=$relative.EndsWith('.g.dart')}
  }
  $verified|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $delivery 'verified-apk-inputs.json') -Encoding utf8
  $index=Join-Path $project '.git\index'
  $originalIndex=(Get-FileHash -LiteralPath $index -Algorithm SHA256).Hash
  $savedIndex=[Environment]::GetEnvironmentVariable('GIT_INDEX_FILE','Process')
  $temporaryIndex=Join-Path $project ('.local\review-email-index-'+$RunSuffix)
  if(Test-Path -LiteralPath $temporaryIndex){throw 'Preserving existing review index'}
  try{
    $env:GIT_INDEX_FILE=$temporaryIndex
    & git read-tree $baseline
    if($LASTEXITCODE -ne 0){throw 'Cannot create temporary review index'}
    & git add --all -- .
    if($LASTEXITCODE -ne 0){throw 'Cannot assemble local review snapshot'}
    & git diff --cached --check
    if($LASTEXITCODE -ne 0){throw 'Review contains whitespace errors'}
    $files=@(& git -c core.quotepath=false ls-files)
    $patch=Join-Path $delivery 'full-candidate-vs-main.patch'
    & git diff --cached --binary $baseline "--output=$patch"
    if($LASTEXITCODE -ne 0){throw 'Cannot export complete review diff'}
  }finally{[Environment]::SetEnvironmentVariable('GIT_INDEX_FILE',$savedIndex,'Process')}
  if((Get-FileHash -LiteralPath $index -Algorithm SHA256).Hash -ne $originalIndex){throw 'Original index unexpectedly changed'}
  $secretPattern='gh[pousr]_[A-Za-z0-9_]{25,}|github_pat_[A-Za-z0-9_]{40,}|-----BEGIN (?:RSA |EC )?PRIVATE KEY-----\r?\n[A-Za-z0-9+/=\r\n]{80}'
  $entries=foreach($relative in $files){
    if($relative -match '(^|/)(\.git|\.local|build|deliverables|\.dart_tool)/|\.g\.dart$|\.(sqlite|keystore|jks)$'){throw "Non-source file in review: $relative"}
    $source=Join-Path $project $relative
    if([Text.Encoding]::Latin1.GetString([IO.File]::ReadAllBytes($source)) -match $secretPattern){throw "Potential credential in source: $relative"}
    [PSCustomObject]@{path=$relative;sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant();canonicalSha256=Get-CanonicalHash $source}
  }
  $manifest=[ordered]@{baseline=$baseline;candidateCommit=$null;branch='codex/v030-control-implementation';version='0.3.0+5';contract='3.0.0';schema=4;json=3;recovery=3;feedback='User-confirmed email composer; no backend';patchSha256=(Get-FileHash -LiteralPath $patch -Algorithm SHA256).Hash.ToLowerInvariant();credentialPatternFindings=0;originalIndexUnchanged=$true;files=$entries}
  $check=Join-Path $project ('.local\patch-review-check-'+$RunSuffix)
  if(Test-Path -LiteralPath $check){throw 'Preserving prior patch verification checkout'}
  & git clone --no-hardlinks --no-checkout $project $check
  & git -C $check checkout -b codex/v030-patch-review $baseline
  & git -C $check apply --check $patch
  if($LASTEXITCODE -ne 0){throw 'Complete patch does not apply to real main baseline'}
  & git -C $check apply --binary $patch
  if($LASTEXITCODE -ne 0){throw 'Patch application failed'}
  $eolOnly=@()
  foreach($entry in $entries){
    $peer=Join-Path $check $entry.path
    if((Get-FileHash -LiteralPath $peer -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256){
      if((Get-CanonicalHash $peer) -ne $entry.canonicalSha256){throw "Patch content differs: $($entry.path)"}
      $eolOnly+=$entry.path
    }
  }
  $manifest['patchComparison']='UTF-8 text CRLF normalized to LF only; binary files exact'
  $manifest['patchLineEndingOnlyDifferences']=$eolOnly
  $manifestJson=$manifest|ConvertTo-Json -Depth 6
  $manifestJson|Set-Content -LiteralPath (Join-Path $delivery 'source-manifest.json') -Encoding utf8
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zipPath=Join-Path $delivery 'PocketFlow-0.3.0-source-local-candidate.zip'
  if(Test-Path -LiteralPath $zipPath){throw 'Preserving existing source archive'}
  $archive=[IO.Compression.ZipFile]::Open($zipPath,[IO.Compression.ZipArchiveMode]::Create)
  try{
    foreach($entry in $entries){[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $project $entry.path),$entry.path)|Out-Null}
    $manifestEntry=$archive.CreateEntry('SOURCE_MANIFEST.json')
    $writer=[IO.StreamWriter]::new($manifestEntry.Open(),[Text.UTF8Encoding]::new($false))
    try{$writer.Write($manifestJson)}finally{$writer.Dispose()}
  }finally{$archive.Dispose()}
  $archive=[IO.Compression.ZipFile]::OpenRead($zipPath)
  try{
    if($archive.Entries.Count -ne $entries.Count+1){throw 'Incomplete archive'}
    foreach($entry in $entries){
      $stream=$archive.GetEntry($entry.path).Open()
      try{$hasher=[Security.Cryptography.SHA256]::Create();$digest=[Convert]::ToHexString($hasher.ComputeHash($stream)).ToLowerInvariant()}finally{$stream.Dispose();$hasher.Dispose()}
      if($digest -ne $entry.sha256){throw "Archive verification failed: $($entry.path)"}
    }
  }finally{$archive.Dispose()}
  ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($zipPath))|Set-Content -LiteralPath ($zipPath+'.sha256') -Encoding ascii
  [PSCustomObject]@{sourceFiles=$entries.Count;verifiedAppInputs=$verified.Count;completePatchApplies=$true;patchContentMatchesEverySourceFile=$true;lineEndingOnlyDifferences=$eolOnly;archiveEveryFileVerified=$true;credentialPatternFindings=0;originalIndexUnchanged=$true;archive=$zipPath}|ConvertTo-Json
}finally{Pop-Location}
