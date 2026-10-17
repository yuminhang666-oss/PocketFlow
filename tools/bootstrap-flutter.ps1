param([string]$ToolRoot = 'D:\Codex\PocketFlowTools')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$pin = Get-Content (Join-Path $PSScriptRoot 'flutter-toolchain.json') -Raw | ConvertFrom-Json
if ([IO.Path]::GetFullPath($ToolRoot) -match '[^\x20-\x7E]|\s') {
    throw 'Choose an ASCII tool directory without spaces.'
}
$manifest = Invoke-RestMethod ($pin.baseUrl + '/releases_windows.json') -TimeoutSec 30
$release = @($manifest.releases | Where-Object { $_.hash -eq $pin.revision -and $_.channel -eq 'stable' })
if ($release.Count -ne 1 -or $release[0].sha256 -ne $pin.sha256 -or
    $release[0].archive -ne $pin.archive -or $release[0].dart_sdk_version -ne $pin.dartVersion) {
    throw 'Pinned release does not match the official Flutter release manifest.'
}
$downloads = Join-Path $ToolRoot 'downloads'
New-Item -ItemType Directory -Path $downloads -Force | Out-Null
$archive = Join-Path $downloads ([IO.Path]::GetFileName($pin.archive))
if (-not (Test-Path -LiteralPath $archive)) {
    $partial = $archive + '.partial'
    if (Test-Path -LiteralPath $partial) { throw 'An unfinished download exists; inspect it before retrying.' }
    Invoke-WebRequest ($pin.baseUrl + '/' + $pin.archive) -OutFile $partial -TimeoutSec 1800
    if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pin.sha256) {
        throw 'Flutter archive SHA256 mismatch; the download was retained for diagnosis.'
    }
    Move-Item -LiteralPath $partial -Destination $archive
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pin.sha256) {
    throw 'Existing archive SHA256 mismatch. No files were replaced.'
}
$destination = Join-Path $ToolRoot $pin.version
if (-not (Test-Path -LiteralPath $destination)) {
    Expand-Archive -LiteralPath $archive -DestinationPath $destination
} elseif (-not (Test-Path (Join-Path $destination 'flutter\bin\flutter.bat'))) {
    throw 'An incomplete installation exists; inspect it before retrying.'
}
. (Join-Path $PSScriptRoot 'enter-pocketflow.ps1') -ToolRoot $ToolRoot
& flutter --suppress-analytics --version
if ($LASTEXITCODE -ne 0) { throw 'Flutter version check failed.' }
& dart --version
if ($LASTEXITCODE -ne 0) { throw 'Dart version check failed.' }
