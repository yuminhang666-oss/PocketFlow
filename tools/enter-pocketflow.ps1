# Dot-source this file. All environment changes apply only to this process.
param(
    [string]$ToolRoot = 'D:\Codex\PocketFlowTools',
    [Uri]$ProxyUri
)
$ErrorActionPreference = 'Stop'
$pin = Get-Content (Join-Path $PSScriptRoot 'flutter-toolchain.json') -Raw | ConvertFrom-Json
$env:FLUTTER_ROOT = Join-Path $ToolRoot ($pin.version + '\flutter')
if (-not (Test-Path (Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'))) {
    throw 'Pinned Flutter SDK is missing. Run tools/bootstrap-flutter.ps1 first.'
}
$env:PUB_CACHE = Join-Path $ToolRoot 'cache\pub'
$env:GRADLE_USER_HOME = Join-Path $ToolRoot 'cache\gradle'
$env:TEMP = Join-Path $ToolRoot 'cache\tmp'
$env:TMP = $env:TEMP
foreach ($directory in @($env:PUB_CACHE, $env:GRADLE_USER_HOME, $env:TEMP)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
$env:PATH = (Join-Path $env:FLUTTER_ROOT 'bin') + ';' + $env:PATH
$env:CI = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
if (-not $ProxyUri) {
    $probe = [Uri]'https://github.com'
    $detected = [System.Net.WebRequest]::DefaultWebProxy.GetProxy($probe)
    if ($detected -and $detected.AbsoluteUri -ne $probe.AbsoluteUri) { $ProxyUri = $detected }
}
if ($ProxyUri) {
    if ($ProxyUri.UserInfo) { throw 'Use locally configured proxy authentication; do not embed credentials in proxy URLs.' }
    $env:HTTPS_PROXY = $ProxyUri.AbsoluteUri
    $env:HTTP_PROXY = $ProxyUri.AbsoluteUri
    $localBypass = 'localhost,127.0.0.1,::1'
    $env:NO_PROXY = if ($env:NO_PROXY) { $env:NO_PROXY + ',' + $localBypass } else { $localBypass }
    # Append a process-scoped Git configuration instead of changing global Git settings.
    $count = 0
    if ($env:GIT_CONFIG_COUNT) { $count = [int]$env:GIT_CONFIG_COUNT }
    [Environment]::SetEnvironmentVariable("GIT_CONFIG_KEY_$count", 'http.proxy', 'Process')
    [Environment]::SetEnvironmentVariable("GIT_CONFIG_VALUE_$count", $ProxyUri.AbsoluteUri, 'Process')
    $env:GIT_CONFIG_COUNT = [string]($count + 1)
}
Write-Host ('PocketFlow process environment: Flutter ' + $pin.version + '; caches: ' + $ToolRoot)
