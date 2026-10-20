param(
  [ValidateSet('capture','tap','scroll','back','start','viewport','font')][string]$Action='capture',
  [string]$Label='', [string]$Name='screen', [int]$Scrolls=0, [string]$ExpectedLabel='',
  [int]$Width=1080, [int]$Height=1920, [double]$Scale=1.0,
  [string]$ToolRoot='D:\Codex\PocketFlowTools'
)
$ErrorActionPreference='Stop'
# This tool only controls this task's disposable read-only emulator overlay.
$serial='emulator-5586'
$adb=Join-Path $ToolRoot 'android-sdk\platform-tools\adb.exe'
if((& $adb -s $serial get-serialno).Trim() -ne $serial){throw 'Expected isolated emulator is unavailable'}
if($Name -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Use a plain evidence name'}
$project=Split-Path $PSScriptRoot -Parent
$evidence=Join-Path $project 'deliverables\v0.3.0\evidence\android'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
function Read-Ui {
  & $adb -s $serial shell uiautomator dump /sdcard/pf-qa-ui.xml | Out-Null
  & $adb -s $serial pull /sdcard/pf-qa-ui.xml (Join-Path $evidence ($Name+'.xml')) 2>&1 | Out-Null
  return [xml](Get-Content -LiteralPath (Join-Path $evidence ($Name+'.xml')) -Raw -Encoding utf8)
}
switch($Action){
  start { & $adb -s $serial shell am start -n cn.pocketflow/.MainActivity; break }
  back { & $adb -s $serial shell input keyevent 4; break }
  scroll { & $adb -s $serial shell input swipe 500 1450 500 450 350; break }
  viewport { & $adb -s $serial shell wm size "${Width}x${Height}"; & $adb -s $serial shell wm density 480; break }
  font { if($Scale -notin @(1.0,1.3,2.0)){throw 'Unexpected test font scale'}; & $adb -s $serial shell settings put system font_scale $Scale.ToString([Globalization.CultureInfo]::InvariantCulture); break }
  tap {
    $found=$null
    for($attempt=0;$attempt -le $Scrolls;$attempt++){
      $ui=Read-Ui
      $clickable=@($ui.SelectNodes('//node') | Where-Object {$_.GetAttribute('clickable') -eq 'true' -and $_.GetAttribute('enabled') -eq 'true'})
      $found=@($clickable | Where-Object {$_.GetAttribute('content-desc') -eq $Label -or $_.GetAttribute('text') -eq $Label -or $_.GetAttribute('hint') -eq $Label}) | Select-Object -First 1
      if(-not $found){$found=@($clickable | Where-Object {$_.GetAttribute('class') -eq 'android.widget.EditText' -and $_.GetAttribute('hint').Contains($Label)}) | Select-Object -First 1}
      if(-not $found){$found=@($clickable | Where-Object {$_.GetAttribute('content-desc').Contains($Label) -or $_.GetAttribute('text').Contains($Label)}) | Select-Object -First 1}
      if($found){break}
      if($attempt -lt $Scrolls){ & $adb -s $serial shell input swipe 500 1450 500 450 350 }
    }
    if(-not $found){throw "Visible clickable label not found: $Label"}
    $bounds=[regex]::Matches($found.GetAttribute('bounds'),'\d+') | ForEach-Object {[int]$_.Value}
    & $adb -s $serial shell input tap ([int](($bounds[0]+$bounds[2])/2)) ([int](($bounds[1]+$bounds[3])/2))
    break
  }
  capture {
    $ui=Read-Ui
    if($ExpectedLabel -and -not @($ui.SelectNodes('//node') | Where-Object {$_.GetAttribute('content-desc').Contains($ExpectedLabel) -or $_.GetAttribute('text').Contains($ExpectedLabel)}).Count){throw "Unexpected screen; missing label: $ExpectedLabel"}
    & $adb -s $serial shell screencap -p /sdcard/pf-qa-screen.png
    & $adb -s $serial pull /sdcard/pf-qa-screen.png (Join-Path $evidence ($Name+'.png')) 2>&1 | Out-Null
    $ui.SelectNodes('//node') | ForEach-Object {$_.GetAttribute('content-desc')} | Where-Object {$_} | Select-Object -First 12
  }
}
