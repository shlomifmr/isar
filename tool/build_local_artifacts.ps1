#Requires -Version 5.1
<#!
Build local native artifacts for Isar and place them into the plugin directories,
skipping any GitHub upload/download and pub.dev publish steps.

This script focuses on Android ABIs, mirroring the relevant parts of release.yaml.
It builds libisar.so for arm64-v8a, armeabi-v7a, x86_64, and x86 and writes them into:
  packages\isar_flutter_libs\android\src\main\jniLibs\<abi>\libisar.so

Prerequisites:
- Rust toolchain installed
- ANDROID_NDK_HOME environment variable set to your NDK path
- cargo-ndk installed (the script will install it if missing)

Usage (PowerShell):
  pwsh -File tool/build_local_artifacts.ps1

Optional parameters:
  -Release       Build in release mode (default: Debug)
  -Crate         The Rust crate package name to build (default: isar)
  -OutRoot       Override jniLibs output root (default: packages/isar_flutter_libs/android/src/main/jniLibs)
#>
param(
  [string]$Crate = "isar",
  [string]$OutRoot = "packages/isar_flutter_libs/android/src/main/jniLibs"
)

$ErrorActionPreference = 'Stop'

function Ensure-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' not found in PATH."
  }
}

Write-Host "==> Building local Android artifacts for Isar (crate: $Crate)" -ForegroundColor Cyan

# Verify NDK env
if (-not $env:ANDROID_NDK_HOME) {
  throw "ANDROID_NDK_HOME is not set. Please set it to your Android NDK path, e.g. C:\Android\ndk\25.2.9519653"
}

# Ensure rustup & cargo available
Ensure-Command rustup
Ensure-Command cargo

# Add required targets
$targets = @(
  'aarch64-linux-android',
  'armv7-linux-androideabi',
  'x86_64-linux-android',
  'i686-linux-android'
)
foreach ($t in $targets) { rustup target add $t | Out-Null }

# Install cargo-ndk if missing
if (-not (Get-Command cargo-ndk -ErrorAction SilentlyContinue)) {
  Write-Host "Installing cargo-ndk..." -ForegroundColor Yellow
  cargo install cargo-ndk
}

# Build flags
$modeArg = "--release"

# Output directories mapping
$abiMap = @{
  'arm64-v8a'   = 'aarch64-linux-android';
  'armeabi-v7a' = 'armv7-linux-androideabi';
  'x86_64'      = 'x86_64-linux-android';
  'x86'         = 'i686-linux-android';
}

# Ensure output root exists
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null

# Build each ABI and output directly into jniLibs
foreach ($abi in $abiMap.Keys) {
  $targetTriple = $abiMap[$abi]
  $abiOut = Join-Path $OutRoot $abi
  New-Item -ItemType Directory -Force -Path $abiOut | Out-Null

  Write-Host "--> Building for $abi ($targetTriple)" -ForegroundColor Green
  # cargo ndk will place libisar.so into the specified output directory
  cargo ndk -t $abi -o $OutRoot build -p $Crate $modeArg

  $soPath = Join-Path $abiOut 'libisar.so'
  if (-not (Test-Path $soPath)) {
    throw "Build succeeded but '$soPath' not found. Verify cargo-ndk output and crate name ($Crate)."
  }
  Write-Host "    Created: $soPath" -ForegroundColor DarkGreen
}

Write-Host "==> All Android ABIs built and placed under '$OutRoot'" -ForegroundColor Cyan

# Optional: quick guidance for verification
Write-Host "You can verify ELF segment alignment (Align 0x4000) with 'readelf -l' if available." -ForegroundColor Gray

# Always build iOS xcframework locally
Write-Host "==> Building iOS xcframework locally" -ForegroundColor Cyan
# We rely on existing build_ios.sh via a bash environment (WSL or Git Bash)
# This will produce isar.xcframework and zip it as isar_ios.xcframework.zip in repo root
$bash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bash) {
  throw "bash is required to run tool/build_ios.sh. Please use WSL or install Git Bash."
}
& bash tool/build_ios.sh
$xcZip = Join-Path (Get-Location) 'isar_ios.xcframework.zip'
if (-not (Test-Path $xcZip)) {
  throw "Expected artifact '$xcZip' not found after iOS build."
}
$iosOutDir = "packages/isar_flutter_libs/ios"
New-Item -ItemType Directory -Force -Path $iosOutDir | Out-Null
Copy-Item $xcZip (Join-Path $iosOutDir 'isar_ios.xcframework.zip') -Force
Write-Host "Copied iOS xcframework zip to '$iosOutDir'" -ForegroundColor DarkGreen
# Unzip into destination
Write-Host "Unzipping xcframework into '$iosOutDir'" -ForegroundColor Gray
Expand-Archive -LiteralPath (Join-Path $iosOutDir 'isar_ios.xcframework.zip') -DestinationPath $iosOutDir -Force
Remove-Item (Join-Path $iosOutDir 'isar_ios.xcframework.zip') -Force
Write-Host "iOS xcframework prepared under '$iosOutDir'" -ForegroundColor Cyan
