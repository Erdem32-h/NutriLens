# Build a production Android AAB with the same dart-defines as Codemagic's
# `android-internal` workflow. Run from anywhere:
#     pwsh scripts/build_android_release.ps1
#
# Why this exists: a bare `flutter build appbundle --release` reads SUPABASE /
# RevenueCat / Anthropic from the bundled .env (fine), but the AdMob ad-unit IDs
# and SENTRY_DSN are compile-time `String.fromEnvironment` values. Without the
# --dart-define flags below the release silently ships Google TEST ad units
# (zero revenue + AdMob policy risk, see lib/core/constants/ad_constants.dart)
# and no crash reporting. This script wires them from .env so the local AAB
# matches what Codemagic produces.
#
# versionCode comes from pubspec.yaml's `version: x.y.z+N` (the +N). Bump it
# before each Play upload — Play rejects a versionCode it has already seen.

$ErrorActionPreference = 'Stop'

# Project root = parent of this script's folder.
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path '.env')) {
  throw ".env not found in $root — put your PRODUCTION .env there first."
}

# Parse .env (KEY=VALUE; skip blanks/comments).
$envMap = @{}
foreach ($line in Get-Content '.env') {
  $t = $line.Trim()
  if ($t -eq '' -or $t.StartsWith('#')) { continue }
  $i = $t.IndexOf('=')
  if ($i -lt 1) { continue }
  $envMap[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim()
}

function Get-Val([string]$key) {
  if ($envMap.ContainsKey($key) -and $envMap[$key]) { return $envMap[$key] }
  $sys = [Environment]::GetEnvironmentVariable($key)
  if ($sys) { return $sys }
  return ''
}

$supabaseUrl   = Get-Val 'SUPABASE_URL'
$supabaseAnon  = Get-Val 'SUPABASE_ANON_KEY'
$sentryDsn     = Get-Val 'SENTRY_DSN'
$admobBanner   = Get-Val 'ADMOB_BANNER_ANDROID'
$admobRewarded = Get-Val 'ADMOB_REWARDED_ANDROID'
$privacyUrl    = Get-Val 'PRIVACY_POLICY_URL'
$termsUrl      = Get-Val 'TERMS_OF_USE_URL'

# Hard guards — shipping without these is a real production defect.
$missing = @()
if (-not $supabaseUrl)   { $missing += 'SUPABASE_URL' }
if (-not $supabaseAnon)  { $missing += 'SUPABASE_ANON_KEY' }
if (-not $admobBanner)   { $missing += 'ADMOB_BANNER_ANDROID (else TEST ads ship)' }
if (-not $admobRewarded) { $missing += 'ADMOB_REWARDED_ANDROID (else TEST ads ship)' }
if ($missing.Count -gt 0) {
  throw "Missing required .env values: $($missing -join ', ')"
}
if (-not $sentryDsn) {
  Write-Warning 'SENTRY_DSN not set — this release will have NO crash reporting.'
}

$defines = @(
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseAnon",
  "--dart-define=ADMOB_BANNER_ANDROID=$admobBanner",
  "--dart-define=ADMOB_REWARDED_ANDROID=$admobRewarded"
)
if ($sentryDsn)  { $defines += "--dart-define=SENTRY_DSN=$sentryDsn" }
if ($privacyUrl) { $defines += "--dart-define=PRIVACY_POLICY_URL=$privacyUrl" }
if ($termsUrl)   { $defines += "--dart-define=TERMS_OF_USE_URL=$termsUrl" }

$ver = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value
Write-Host "Building release AAB  (version: $ver)" -ForegroundColor Cyan

flutter build appbundle --release @defines
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed.' }

Write-Host ''
Write-Host 'AAB ready: build/app/outputs/bundle/release/app-release.aab' -ForegroundColor Green
Write-Host 'Upload to Play Console. If it rejects the versionCode, bump the +N in pubspec.yaml and rerun.' -ForegroundColor Green
