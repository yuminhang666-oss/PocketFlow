param([Parameter(Mandatory=$true)][string]$ApkPath,[string]$ToolRoot='D:\Codex\PocketFlowTools')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'enter-android.ps1') -ToolRoot $ToolRoot
$project=Split-Path $PSScriptRoot -Parent
$output=Join-Path $project '.local\qa\apk-native-inspection'
New-Item -ItemType Directory -Path $output -Force | Out-Null
$apk=(Resolve-Path -LiteralPath $ApkPath).Path
$badging=& (Join-Path $env:ANDROID_HOME 'build-tools\36.0.0\aapt.exe') dump badging $apk
if($LASTEXITCODE -ne 0 -or ($badging | Select-String '^application-debuggable')){throw 'Not a non-debuggable Release APK'}
$minApi=[int][regex]::Match(($badging -join "`n"),"sdkVersion:'([0-9]+)'").Groups[1].Value
$readElf=Join-Path $env:ANDROID_HOME 'ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readelf.exe'
$secretPattern='gh[pousr]_[A-Za-z0-9_]{25,}|github_pat_[A-Za-z0-9_]{40,}|-----BEGIN (?:RSA |EC )?PRIVATE KEY-----\r?\n[A-Za-z0-9+/=\r\n]{80}'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($apk)
$native=@()
try{
  if($archive.GetEntry('assets/flutter_assets/kernel_blob.bin')){throw 'Debug kernel found in candidate'}
  foreach($abi in @('arm64-v8a','armeabi-v7a','x86_64')){if(-not $archive.GetEntry("lib/$abi/libapp.so")){throw "AOT app missing for $abi"}}
  foreach($entry in $archive.Entries){
    if($entry.Length -eq 0){continue}
    $stream=$entry.Open();$buffer=[IO.MemoryStream]::new()
    try{$stream.CopyTo($buffer);$bytes=$buffer.ToArray()}finally{$stream.Dispose();$buffer.Dispose()}
    if([Text.Encoding]::Latin1.GetString($bytes) -match $secretPattern){throw "Potential credential material in APK entry: $($entry.FullName)"}
    if($entry.FullName -match '^lib/(arm64-v8a|armeabi-v7a|x86_64)/([a-zA-Z0-9._-]+\.so)$'){
      $abi=$Matches[1];$library=$Matches[2];$path=Join-Path $output ($abi+'-'+$library)
      [IO.File]::WriteAllBytes($path,$bytes)
      $headers=& $readElf -lW $path
      if($LASTEXITCODE -ne 0){throw "ELF inspection failed: $($entry.FullName)"}
      $alignments=@($headers | Where-Object {$_ -match '^\s*LOAD\s'} | ForEach-Object {[Convert]::ToInt64(([regex]::Match($_,'0x[0-9a-fA-F]+\s*$')).Value.Trim().Substring(2),16)})
      if($alignments.Count -eq 0 -or @($alignments | Where-Object {$_ -lt 16384}).Count -gt 0){throw "ELF LOAD alignment below 16KiB: $($entry.FullName)"}
      $native += [PSCustomObject]@{entry=$entry.FullName;loadAlignments=$alignments}
    }
  }
}finally{$archive.Dispose()}
[PSCustomObject]@{apk=$apk;bytes=(Get-Item -LiteralPath $apk).Length;sha256=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant();minAndroidApi=$minApi;debuggable=$false;mode='Release AOT';native=$native;credentialPatternFindings=0;permissions=@($badging | Where-Object {$_ -match '^uses-permission:'})}|ConvertTo-Json -Depth 5
