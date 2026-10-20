param(
    [Parameter(Mandatory=$true)][string]$ApkPath,
    [string]$ToolRoot = 'D:\Codex\PocketFlowTools',
    [int]$MinimumVersionCode = 5
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'enter-android.ps1') -ToolRoot $ToolRoot
$pin = Get-Content (Join-Path $PSScriptRoot 'android-test-signing.json') -Raw | ConvertFrom-Json
$aapt = Join-Path $env:ANDROID_HOME 'build-tools\36.0.0\aapt.exe'
$signer = Join-Path $env:ANDROID_HOME 'build-tools\36.0.0\apksigner.bat'
$nativeApkPath = (Resolve-Path -LiteralPath $ApkPath).Path
if ($nativeApkPath -match '[^\x20-\x7E]') {
    # aapt on Windows cannot open a non-ASCII path. Inspect an identical cache
    # copy while keeping the delivered file at the user's requested location.
    $originalHash = (Get-FileHash -LiteralPath $nativeApkPath -Algorithm SHA256).Hash
    $nativeApkPath = Join-Path $env:TEMP ('apk-inspection-' + $originalHash.Substring(0,16) + '.apk')
    if (-not (Test-Path -LiteralPath $nativeApkPath)) {
        Copy-Item -LiteralPath $ApkPath -Destination $nativeApkPath
    }
    if ((Get-FileHash -LiteralPath $nativeApkPath -Algorithm SHA256).Hash -ne $originalHash) {
        throw 'The ASCII inspection copy differs from the original APK.'
    }
}
$metadata = & $aapt dump badging $nativeApkPath
if ($LASTEXITCODE -ne 0) { throw 'Cannot read APK metadata.' }
$packageLine = $metadata | Where-Object { $_.StartsWith('package:') } | Select-Object -First 1
$package = [regex]::Match($packageLine, "name='([^']+)'").Groups[1].Value
$versionCode = [int][regex]::Match($packageLine, "versionCode='([0-9]+)'").Groups[1].Value
$versionName = [regex]::Match($packageLine, "versionName='([^']+)'").Groups[1].Value
if ($package -ne $pin.applicationId -or $versionCode -lt $MinimumVersionCode) {
    throw 'APK package/version is incompatible with the intended update.'
}
$signature = & $signer verify --verbose --print-certs $nativeApkPath
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
$certificate = ($signature | Select-String '^Signer #1 certificate SHA-256 digest: (.+)$').Matches[0].Groups[1].Value
if ($certificate -ne $pin.certificateSha256) {
    throw 'APK signing certificate differs from the installed 0.1.0 APK. Do not publish this file as an update.'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ApkPath).Path)
try {
    $requiredClasses = @(
        'Lio/flutter/plugins/GeneratedPluginRegistrant;',
        'Lcom/github/dart_lang/jni/JniPlugin;',
        'Lcom/github/dart_lang/jni_flutter/JniFlutterPlugin;'
    )
    $found = @{}
    foreach ($entry in $zip.Entries | Where-Object { $_.FullName -match '^classes[0-9]*\.dex$' }) {
        $source = $entry.Open()
        $buffer = [IO.MemoryStream]::new()
        try {
            $source.CopyTo($buffer)
            $strings = [Text.Encoding]::Latin1.GetString($buffer.ToArray())
            foreach ($className in $requiredClasses) {
                if ($strings.Contains($className)) { $found[$className] = $true }
            }
        } finally { $source.Dispose(); $buffer.Dispose() }
    }
    foreach ($className in $requiredClasses) {
        if (-not $found[$className]) { throw "Required Android plugin class missing from the APK: $className" }
    }
    $abiLine = $metadata | Where-Object { $_.StartsWith('native-code:') } | Select-Object -First 1
    $abis = @([regex]::Matches($abiLine, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
    if ($abis.Count -eq 0) { throw 'APK has no native ABI metadata.' }
    foreach ($abi in $abis) {
        foreach ($library in @('libflutter.so', 'libsqlite3.so', 'libdartjni.so')) {
            if (-not $zip.GetEntry("lib/$abi/$library")) {
                throw "Required native library is missing for ${abi}: $library"
            }
        }
    }
} finally { $zip.Dispose() }
$file = Get-Item -LiteralPath $ApkPath
[PSCustomObject]@{
    ApplicationId = $package
    VersionCode = $versionCode
    VersionName = $versionName
    CertificateSha256 = $certificate
    Bytes = $file.Length
    Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    RequiredNativePluginsPresent = $true
    NativeAbis = $abis
} | ConvertTo-Json
