param([string]$ToolRoot='D:\Codex\PocketFlowTools',[string]$SnapshotName='clean-v030-20261020')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
if($SnapshotName -notmatch '^clean-[a-z0-9-]+$'){throw 'Invalid snapshot name'}
$destination=[IO.Path]::GetFullPath((Join-Path $project ('.local\'+$SnapshotName)))
if(-not $destination.StartsWith($project+'\.local\')){throw 'Clean checkout must stay within this task workspace'}
if(Test-Path -LiteralPath $destination){throw 'Preserving existing clean verification checkout; inspect it before running again'}
$baseline='b4f7aa6edea3bcc90d563015252c4e1fcd900649'
Push-Location -LiteralPath $project
try {
  $files=@(& git ls-files -co --exclude-standard) | Sort-Object -Unique
  if($LASTEXITCODE -ne 0){throw 'Cannot enumerate source snapshot'}
  if($files | Where-Object {$_ -match '(^|/)(\.dart_tool|build|deliverables|\.git)/|\.g\.dart$|\.(sqlite|keystore|jks)$'}){throw 'Generated/private files in source snapshot'}
  & git clone --no-hardlinks --no-checkout $project $destination
  if($LASTEXITCODE -ne 0){throw 'Independent local clone failed'}
  & git -C $destination checkout -b codex/v030-clean-verification $baseline
  if($LASTEXITCODE -ne 0){throw 'Cannot check out verified baseline'}
  $manifest=foreach($relative in $files){
    $source=Join-Path $project $relative
    $target=Join-Path $destination $relative
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
    $hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash){throw "Copy mismatch: $relative"}
    [PSCustomObject]@{path=$relative;sha256=$hash}
  }
  $evidence=Join-Path $project 'deliverables\v0.3.0\evidence\clean'
  New-Item -ItemType Directory -Path $evidence -Force | Out-Null
  [PSCustomObject]@{baseline=$baseline;candidateCommit=$null;source=$project;cleanCheckout=$destination;files=$manifest}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $evidence ($SnapshotName+'-source-manifest.json')) -Encoding utf8
  . (Join-Path $destination 'tools\enter-android.ps1') -ToolRoot $ToolRoot
  Set-Location -LiteralPath $destination
  & flutter pub get --offline --enforce-lockfile
  if($LASTEXITCODE -ne 0){throw 'Locked offline resolution failed'}
  & (Join-Path $destination 'tools\verify.ps1') -ToolRoot $ToolRoot
  & (Join-Path $destination 'tools\build-release-candidate.ps1') -ToolRoot $ToolRoot
  Write-Output "Clean generation, analysis, tests and Release build completed: $destination"
} finally {Pop-Location}
