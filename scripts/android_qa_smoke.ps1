param(
  [string]$Serial = "",
  [string]$Package = "com.nutrilensapp.android",
  [ValidateSet("debug", "release")]
  [string]$BuildMode = "debug",
  [switch]$SkipBuild,
  [switch]$UninstallFirst,
  [switch]$NavigateTabs,
  [switch]$CapturePerformance,
  [string]$ArtifactDir = "build/qa/android"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

function Run-Step {
  param(
    [string]$Name,
    [scriptblock]$Command
  )

  Write-Host "==> $Name"
  & $Command
}

function Invoke-Adb {
  if ($Serial -ne "") {
    & adb -s $Serial @args
  } else {
    & adb @args
  }

  if ($LASTEXITCODE -ne 0) {
    throw "adb command failed with exit code ${LASTEXITCODE}: adb $($args -join ' ')"
  }
}

function Save-AdbBinary {
  param(
    [string[]]$AdbArgs,
    [string]$OutputPath
  )

  $allArgs = @()
  if ($Serial -ne "") {
    $allArgs += @("-s", $Serial)
  }
  $allArgs += $AdbArgs

  $process = Start-Process `
    -FilePath "adb" `
    -ArgumentList $allArgs `
    -RedirectStandardOutput $OutputPath `
    -NoNewWindow `
    -Wait `
    -PassThru

  if ($process.ExitCode -ne 0) {
    throw "adb binary capture failed with exit code $($process.ExitCode)."
  }
}

function Save-UiTree {
  param([string]$OutputPath)

  Invoke-Adb exec-out uiautomator dump /dev/tty |
    Out-File -Encoding utf8 $OutputPath
}

function Get-BottomNavCenters {
  param([string]$UiPath)

  $content = Get-Content -Raw -Path $UiPath
  $rootMatch = [regex]::Match($content, 'bounds="\[0,0\]\[(\d+),(\d+)\]"')
  if (-not $rootMatch.Success) {
    throw "Could not find root bounds in $UiPath."
  }

  $screenHeight = [int]$rootMatch.Groups[2].Value
  $bottomThreshold = [math]::Floor($screenHeight * 0.80)
  $matches = [regex]::Matches($content, '<node\b[^>]*>')

  $centers = foreach ($match in $matches) {
    $node = $match.Value
    if ($node -notmatch 'clickable="true"') {
      continue
    }

    $boundsMatch = [regex]::Match($node, 'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
    if (-not $boundsMatch.Success) {
      continue
    }

    $x1 = [int]$boundsMatch.Groups[1].Value
    $y1 = [int]$boundsMatch.Groups[2].Value
    $x2 = [int]$boundsMatch.Groups[3].Value
    $y2 = [int]$boundsMatch.Groups[4].Value
    if ($y1 -ge $bottomThreshold) {
      [pscustomobject]@{
        X = [math]::Floor(($x1 + $x2) / 2)
        Y = [math]::Floor(($y1 + $y2) / 2)
      }
    }
  }

  $unique = $centers |
    Sort-Object X, Y |
    Group-Object X |
    ForEach-Object { $_.Group | Select-Object -First 1 }

  if (($unique | Measure-Object).Count -lt 5) {
    throw "NavigateTabs requires an authenticated app session with the bottom navigation visible. Found $(($unique | Measure-Object).Count) bottom navigation target(s); the app may be on the login/onboarding screen."
  }

  return $unique | Select-Object -First 5
}

function Capture-CurrentScreen {
  param([string]$Name)

  Save-UiTree -OutputPath (Join-Path $ArtifactDir "$Name-ui.xml")
  Save-AdbBinary `
    -AdbArgs @("exec-out", "screencap", "-p") `
    -OutputPath (Join-Path $ArtifactDir "$Name-screenshot.png")
}

function Count-FileMatches {
  param(
    [string]$Path,
    [string]$Pattern
  )

  if (-not (Test-Path $Path)) {
    return 0
  }

  return @(Select-String -Path $Path -Pattern $Pattern -CaseSensitive:$false).Count
}

function Get-LaunchMetric {
  param(
    [string]$Path,
    [string]$Name
  )

  if (-not (Test-Path $Path)) {
    return $null
  }

  $match = [regex]::Match((Get-Content -Raw -Path $Path), "$Name`: (\d+)")
  if ($match.Success) {
    return [int]$match.Groups[1].Value
  }

  return $null
}

function Write-QaSummary {
  $launchPath = Join-Path $ArtifactDir "launch.txt"
  $crashPath = Join-Path $ArtifactDir "crash.txt"
  $logcatPath = Join-Path $ArtifactDir "logcat.txt"

  $navScreens = Get-ChildItem -Path $ArtifactDir -Filter "nav-*-screenshot.png" -ErrorAction SilentlyContinue |
    Sort-Object Name |
    ForEach-Object { $_.Name }

  $summary = [ordered]@{
    generatedAt = (Get-Date).ToString("o")
    package = $Package
    buildMode = $BuildMode
    navigateTabs = [bool]$NavigateTabs
    capturePerformance = [bool]$CapturePerformance
    launchTotalTimeMs = Get-LaunchMetric -Path $launchPath -Name "TotalTime"
    launchWaitTimeMs = Get-LaunchMetric -Path $launchPath -Name "WaitTime"
    crashBytes = if (Test-Path $crashPath) { (Get-Item $crashPath).Length } else { $null }
    fatalExceptionCount = Count-FileMatches -Path $logcatPath -Pattern "FATAL EXCEPTION"
    anrCount = Count-FileMatches -Path $logcatPath -Pattern "\bANR\b"
    revenueCatDebugLogCount = Count-FileMatches -Path $logcatPath -Pattern "\[Purchases\]\s+-\s+DEBUG:|Debug logging enabled"
    purchaseNotAllowedCount = Count-FileMatches -Path $logcatPath -Pattern "PurchaseNotAllowedError|BILLING_UNAVAILABLE"
    navScreens = @($navScreens)
  }

  $summary |
    ConvertTo-Json -Depth 4 |
    Out-File -Encoding utf8 (Join-Path $ArtifactDir "qa-summary.json")
}

New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

Run-Step "List adb devices" {
  adb devices | Tee-Object -FilePath (Join-Path $ArtifactDir "device.txt")
}

if (-not $SkipBuild) {
  Run-Step "Build Flutter APK ($BuildMode)" {
    flutter build apk --$BuildMode
  }
}

$apk = if ($BuildMode -eq "release") {
  "build/app/outputs/flutter-apk/app-release.apk"
} else {
  "build/app/outputs/flutter-apk/app-debug.apk"
}

if (-not (Test-Path $apk)) {
  throw "APK not found at $apk. Run without -SkipBuild or build the APK first."
}

if ($UninstallFirst) {
  Run-Step "Uninstall existing package" {
    Invoke-Adb uninstall $Package
  }
}

Run-Step "Install APK" {
  Invoke-Adb install -r $apk
}

if ($NavigateTabs) {
  Run-Step "Grant camera permission for navigation smoke" {
    Invoke-Adb shell pm grant $Package android.permission.CAMERA
  }
}

Run-Step "Record installed packages" {
  Invoke-Adb shell pm list packages |
    Select-String $Package |
    Tee-Object -FilePath (Join-Path $ArtifactDir "packages.txt")
}

Run-Step "Clear logs" {
  Invoke-Adb logcat -c
}

Run-Step "Force-stop app" {
  Invoke-Adb shell am force-stop $Package
}

$activity = Invoke-Adb shell cmd package resolve-activity --brief $Package |
  Select-Object -Last 1
if (-not $activity) {
  throw "Could not resolve launch activity for $Package."
}

Run-Step "Cold launch app" {
  Invoke-Adb shell am start -W -n $activity |
    Tee-Object -FilePath (Join-Path $ArtifactDir "launch.txt")
}

Start-Sleep -Seconds 5

Run-Step "Capture UI tree" {
  Save-UiTree -OutputPath (Join-Path $ArtifactDir "ui.xml")
}

Run-Step "Capture screenshot" {
  Save-AdbBinary `
    -AdbArgs @("exec-out", "screencap", "-p") `
    -OutputPath (Join-Path $ArtifactDir "screenshot.png")
}

if ($NavigateTabs) {
  Run-Step "NavigateTabs bottom navigation smoke" {
    $navUiPath = Join-Path $ArtifactDir "nav-baseline-ui.xml"
    Save-UiTree -OutputPath $navUiPath
    $targets = @(Get-BottomNavCenters -UiPath $navUiPath)
    $names = @("meals", "history", "scanner", "favorites", "profile")

    for ($i = 0; $i -lt 5; $i++) {
      $target = $targets[$i]
      $name = $names[$i]
      Invoke-Adb shell input tap $target.X $target.Y
      Start-Sleep -Seconds 2
      Capture-CurrentScreen -Name "nav-$name"
    }
  }
}

if ($CapturePerformance) {
  Run-Step "Capture gfxinfo" {
    Invoke-Adb shell dumpsys gfxinfo $Package |
      Out-File -Encoding utf8 (Join-Path $ArtifactDir "gfxinfo.txt")
  }

  Run-Step "Capture meminfo" {
    Invoke-Adb shell dumpsys meminfo $Package |
      Out-File -Encoding utf8 (Join-Path $ArtifactDir "meminfo.txt")
  }
}

Run-Step "Capture logcat" {
  Invoke-Adb logcat -d |
    Out-File -Encoding utf8 (Join-Path $ArtifactDir "logcat.txt")
}

Run-Step "Capture crash buffer" {
  Invoke-Adb logcat -b crash -d |
    Out-File -Encoding utf8 (Join-Path $ArtifactDir "crash.txt")
}

Run-Step "Write QA summary" {
  Write-QaSummary
}

Write-Host "Android QA smoke completed. Artifacts: $ArtifactDir"
