param([string]$ToolRoot = 'D:\Codex\PocketFlowTools')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'enter-android.ps1') -ToolRoot $ToolRoot
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath (Join-Path $root 'android\settings.gradle.kts'))) {
    throw 'Android scaffold must exist before dependency/plugin resolution.'
}
$env:POCKETFLOW_TEST_KEYSTORE = Join-Path $ToolRoot 'signing\pocketflow-test.keystore'
if (-not (Test-Path -LiteralPath $env:POCKETFLOW_TEST_KEYSTORE)) {
    throw 'The existing 0.1.0 test signing key is missing. Do not regenerate it; restore it locally before delivering an update.'
}
Push-Location -LiteralPath $root
try {
    # Never skip this after generating/restoring the Android platform. It also
    # generates the native plugin graph and Java registration, beyond Pub's lock.
    & flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Locked dependency/plugin resolution failed.' }
    $plugins = Get-Content -LiteralPath '.flutter-plugins-dependencies' -Raw | ConvertFrom-Json
    foreach ($name in @('jni', 'jni_flutter')) {
        if (-not ($plugins.plugins.android | Where-Object { $_.name -eq $name -and $_.native_build })) {
            throw "Android native plugin configuration missing: $name"
        }
    }
    & dart run build_runner build --force-jit
    if ($LASTEXITCODE -ne 0) { throw 'Drift generation failed.' }
    & flutter build apk --debug --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
    & (Join-Path $PSScriptRoot 'assert-android-apk.ps1') -ApkPath 'build\app\outputs\flutter-apk\app-debug.apk' -ToolRoot $ToolRoot
} finally { Pop-Location }
