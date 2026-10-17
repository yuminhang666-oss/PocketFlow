param([string]$Repository = 'https://github.com/yuminhang666-oss/PocketFlow.git')
$ErrorActionPreference = 'Stop'
$probe = [Uri]'https://github.com'
$proxy = [System.Net.WebRequest]::DefaultWebProxy.GetProxy($probe)
$gitOptions = @('-c', 'http.connectTimeout=10', '-c', 'http.lowSpeedLimit=1000', '-c', 'http.lowSpeedTime=10')
if ($proxy -and $proxy.AbsoluteUri -ne $probe.AbsoluteUri) {
    if ($proxy.UserInfo) { throw 'Proxy URL contains credentials; configure authentication locally.' }
    $gitOptions += @('-c', ('http.proxy=' + $proxy.AbsoluteUri))
    Write-Host 'Using the existing system proxy for this Git command.'
}
foreach ($target in @(
    'https://github.com',
    'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json',
    'https://pub.dev/api/packages/drift'
)) {
    try {
        $response = Invoke-WebRequest -Uri $target -Method Head -TimeoutSec 20
        Write-Host "$target HTTP $([int]$response.StatusCode)"
    } catch {
        Write-Host "$target failed: $($_.Exception.Message)"
    }
}
$previousPrompt = $env:GIT_TERMINAL_PROMPT
try {
    $env:GIT_TERMINAL_PROMPT = '0'
    & git @gitOptions ls-remote $Repository refs/heads/main refs/heads/chore/d-test-build
    if ($LASTEXITCODE -ne 0) { throw 'Git access failed. Check network and the locally configured credential helper separately.' }
} finally { $env:GIT_TERMINAL_PROMPT = $previousPrompt }
