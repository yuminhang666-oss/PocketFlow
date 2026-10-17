param([string]$ToolRoot = 'D:\Codex\PocketFlowTools')

# Dot-source this file to configure this PowerShell process only.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'enter-pocketflow.ps1') -ToolRoot $ToolRoot
$jdkRoot = Join-Path $ToolRoot 'jdk17'
$jdk = Get-ChildItem -LiteralPath $jdkRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\java.exe') } |
    Select-Object -First 1
if (-not $jdk) { throw "JDK 17 not found under $jdkRoot. Install the approved JDK before building." }
$sdk = Join-Path $ToolRoot 'android-sdk'
if (-not (Test-Path -LiteralPath (Join-Path $sdk 'platforms\android-36\android.jar'))) {
    throw 'Android API 36 is not installed in the selected tool directory.'
}
$env:JAVA_HOME = $jdk.FullName
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:ANDROID_USER_HOME = Join-Path $ToolRoot 'cache\android'
New-Item -ItemType Directory -Path $env:ANDROID_USER_HOME -Force | Out-Null
$env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ';' +
    (Join-Path $sdk 'platform-tools') + ';' +
    (Join-Path $sdk 'cmdline-tools\latest\bin') + ';' + $env:PATH
if ($env:HTTPS_PROXY) {
    $androidProxy = [Uri]$env:HTTPS_PROXY
    if ($androidProxy.Scheme -eq 'http' -and -not $androidProxy.UserInfo) {
        $env:GRADLE_OPTS = ($env:GRADLE_OPTS + ' -Dhttps.proxyHost=' + $androidProxy.Host +
            ' -Dhttps.proxyPort=' + $androidProxy.Port + ' -Dhttp.proxyHost=' +
            $androidProxy.Host + ' -Dhttp.proxyPort=' + $androidProxy.Port).Trim()
    }
}
Write-Host 'Android build environment configured for this process; global settings were not changed.'
