param(
    [string]$ToolRoot = 'D:\Codex\PocketFlowTools',
    [switch]$ResolveDependencies
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'enter-pocketflow.ps1') -ToolRoot $ToolRoot
$root = Split-Path $PSScriptRoot -Parent
if ($env:OS -eq 'Windows_NT' -and $root -match '[^\x20-\x7E]') {
    throw 'This pinned Windows toolchain fails AOT output and LSP analysis under a non-ASCII checkout path. Use an independent ASCII checkout (for example D:\Codex\PocketFlowTools\checkouts\D); do not move another conversation''s worktree.'
}
$evidence = Join-Path $root ('.local\qa\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
function Invoke-Check([string]$Name, [string]$Command, [string[]]$Arguments) {
    & $Command @Arguments 2>&1 | Tee-Object -FilePath (Join-Path $evidence ($Name + '.log')) | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE. See $evidence" }
}
Push-Location $root
try {
    [PSCustomObject]@{ProjectRoot=$root;ToolRoot=$ToolRoot} | ConvertTo-Json | Set-Content (Join-Path $evidence 'context.json')
    $sourceFiles = @(Get-ChildItem 'lib','test' -Recurse -File -Filter '*.dart') +
        @(Get-Item 'pubspec.yaml','analysis_options.yaml')
    $sourceFiles | Get-FileHash -Algorithm SHA256 | ConvertTo-Json | Set-Content (Join-Path $evidence 'source-inputs.json')
    Invoke-Check 'git-head' 'git' @('rev-parse', 'HEAD')
    Invoke-Check 'flutter-version' 'flutter' @('--suppress-analytics', '--version', '--machine')
    $version = Get-Content (Join-Path $evidence 'flutter-version.log') -Raw | ConvertFrom-Json
    $pin = Get-Content (Join-Path $PSScriptRoot 'flutter-toolchain.json') -Raw | ConvertFrom-Json
    if ($version.frameworkRevision -ne $pin.revision) { throw 'Flutter revision differs from pinned toolchain.' }
    if ($ResolveDependencies) {
        $pubArguments = @('--suppress-analytics', 'pub', 'get')
        if (Test-Path 'pubspec.lock') { $pubArguments += '--enforce-lockfile' }
        Invoke-Check 'pub-get' 'flutter' $pubArguments
    } elseif (-not (Test-Path 'pubspec.lock') -or -not (Test-Path '.dart_tool\package_config.json')) {
        throw 'Dependencies are unresolved. Run with -ResolveDependencies to create a candidate lock; the owner must review it.'
    }
    if (Test-Path 'pubspec.lock') {
        Copy-Item -LiteralPath 'pubspec.lock' -Destination (Join-Path $evidence 'pubspec.lock')
        Get-FileHash 'pubspec.lock' -Algorithm SHA256 | ConvertTo-Json | Set-Content (Join-Path $evidence 'lock-sha256.json')
    }
    # Use the supported JIT builder mode consistently on local Windows and CI.
    Invoke-Check 'drift-generation' 'dart' @('run', 'build_runner', 'build', '--force-jit')
    Invoke-Check 'analyze' 'flutter' @('--suppress-analytics', 'analyze', '--no-pub')
    Invoke-Check 'flutter-test' 'flutter' @('--suppress-analytics', 'test', '--no-pub', '--reporter', 'expanded')
    Invoke-Check 'sql-design-test' 'node' @('--test', 'tools/schema.test.mjs')
    Invoke-Check 'feedback-service-test' 'node' @('--test', 'server/feedback/server.test.mjs')
    Write-Host "Verification passed. Evidence: $evidence"
} finally { Pop-Location }
