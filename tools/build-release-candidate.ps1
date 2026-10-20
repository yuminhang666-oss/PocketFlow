param([string]$ToolRoot='D:\Codex\PocketFlowTools')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'enter-android.ps1') -ToolRoot $ToolRoot
$env:POCKETFLOW_TEST_KEYSTORE=Join-Path $ToolRoot 'signing\pocketflow-test.keystore'
if(-not (Test-Path -LiteralPath $env:POCKETFLOW_TEST_KEYSTORE)){throw 'Existing upgrade signing key is required; no new key will be created.'}
$projectRoot=Split-Path $PSScriptRoot -Parent
Push-Location -LiteralPath $projectRoot
try {
  flutter pub get --offline --enforce-lockfile
  if($LASTEXITCODE -ne 0){throw 'Existing locked dependencies are unavailable.'}
  dart run build_runner build --force-jit
  if($LASTEXITCODE -ne 0){throw 'Drift generation failed.'}
  flutter build apk --release --no-pub
  if($LASTEXITCODE -ne 0){throw 'Release build failed.'}
  $delivery=Join-Path $projectRoot 'deliverables\v0.3.0'
  New-Item -ItemType Directory -Path $delivery -Force | Out-Null
  $release=Join-Path $delivery 'PocketFlow-0.3.0-release.apk'
  if(Test-Path -LiteralPath $release){throw 'Candidate already exists; review it before replacing.'}
  Copy-Item -LiteralPath 'build\app\outputs\flutter-apk\app-release.apk' -Destination $release
  & (Join-Path $PSScriptRoot 'assert-android-apk.ps1') -ApkPath $release -ToolRoot $ToolRoot -MinimumVersionCode 5 | Set-Content (Join-Path $delivery 'apk-validation.json')
  if($LASTEXITCODE -ne 0){throw 'APK validation failed.'}
  $compat=Join-Path $delivery 'PocketFlow-0.3.0-debug.apk'
  if(Test-Path -LiteralPath $compat){throw 'Compatibility asset already exists.'}
  Copy-Item -LiteralPath $release -Destination $compat
  if((Get-FileHash -LiteralPath $release).Hash -ne (Get-FileHash -LiteralPath $compat).Hash){throw 'Compatibility copy differs.'}
  $metadata=Get-Content (Join-Path $delivery 'apk-validation.json') -Raw | ConvertFrom-Json
  foreach($schema in @(1,2)){
    $manifest=[ordered]@{schemaVersion=$schema;applicationId=$metadata.ApplicationId;versionName=$metadata.VersionName;versionCode=$metadata.VersionCode;apkSizeBytes=$metadata.Bytes;apkSha256=$metadata.Sha256;certificateSha256=$metadata.CertificateSha256;releaseNotes=@('计划、提醒与回顾本地候选。','实际编译模式为Release，沿用个人测试签名；旧-debug文件名仅用于更新兼容。','反馈改为预览后打开邮件客户端，收件人为yuminhang666@gmail.com，无需反馈服务器；App无法确认邮件是否送达。')}
    if($schema -eq 1){$manifest.apkName='PocketFlow-0.3.0-debug.apk';$name='PocketFlow-update.json'}else{$manifest.buildKind='release';$manifest.assetName='PocketFlow-0.3.0-release.apk';$name='PocketFlow-update-v2.json'}
    $manifest|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $delivery $name) -Encoding utf8
  }
  foreach($file in @($release,$compat)){((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($file))|Set-Content -LiteralPath ($file+'.sha256') -Encoding ascii}
} finally {Pop-Location}
