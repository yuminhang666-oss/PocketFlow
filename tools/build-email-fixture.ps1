param([string]$ToolRoot='D:\Codex\PocketFlowTools')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'enter-android.ps1') -ToolRoot $ToolRoot
$project=Split-Path $PSScriptRoot -Parent
$output=Join-Path $project '.local\qa\mail-sink'
if(Test-Path -LiteralPath $output){throw 'Preserving existing mail test fixture'}
New-Item -ItemType Directory -Path $output,(Join-Path $output 'classes'),(Join-Path $output 'dex') -Force | Out-Null
$sdkJar=Join-Path $env:ANDROID_HOME 'platforms\android-36\android.jar'
$buildTools=Join-Path $env:ANDROID_HOME 'build-tools\36.0.0'
& (Join-Path $env:JAVA_HOME 'bin\javac.exe') -source 8 -target 8 -classpath $sdkJar -d (Join-Path $output 'classes') (Join-Path $PSScriptRoot 'email-handoff-fixture\MailSinkActivity.java')
if($LASTEXITCODE -ne 0){throw 'Synthetic mail receiver compilation failed'}
& (Join-Path $buildTools 'd8.bat') --lib $sdkJar --min-api 24 --output (Join-Path $output 'dex') (Join-Path $output 'classes\cn\pocketflow\testmailsink\MailSinkActivity.class')
if($LASTEXITCODE -ne 0){throw 'Synthetic dex compilation failed'}
$unsigned=Join-Path $output 'unsigned.apk'
& (Join-Path $buildTools 'aapt2.exe') link -I $sdkJar --manifest (Join-Path $PSScriptRoot 'email-handoff-fixture\AndroidManifest.xml') -o $unsigned
if($LASTEXITCODE -ne 0){throw 'Synthetic manifest packaging failed'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::Open($unsigned,[IO.Compression.ZipArchiveMode]::Update)
try{[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $output 'dex\classes.dex'),'classes.dex')|Out-Null}finally{$zip.Dispose()}
$apk=Join-Path $output 'synthetic-email-sink.apk'
& (Join-Path $buildTools 'zipalign.exe') -p 4 $unsigned $apk
if($LASTEXITCODE -ne 0){throw 'Synthetic alignment failed'}
if(-not $env:POCKETFLOW_TEST_KEYSTORE_PASSWORD){throw 'Set the existing test-key password in the local process environment; never paste it into chat or source.'}
& (Join-Path $buildTools 'apksigner.bat') sign --ks (Join-Path $ToolRoot 'signing\pocketflow-test.keystore') --ks-key-alias androiddebugkey --ks-pass env:POCKETFLOW_TEST_KEYSTORE_PASSWORD --key-pass env:POCKETFLOW_TEST_KEYSTORE_PASSWORD $apk
if($LASTEXITCODE -ne 0){throw 'Synthetic fixture signing failed'}
Write-Output $apk
