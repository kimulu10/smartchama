# Build release APK for SmartChama
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

if (-not (Test-Path "android\keystore.properties")) {
    Write-Host "Copy android\keystore.properties.example to android\keystore.properties and set your keystore path." -ForegroundColor Yellow
}

Write-Host "Running flutter pub get..."
flutter pub get

Write-Host "Building release APK (may take several minutes)..."
flutter build apk --release

$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
    $dest = "releases\smartchama-release.apk"
    New-Item -ItemType Directory -Force -Path "releases" | Out-Null
    Copy-Item $apk $dest -Force
    Write-Host "APK ready: $((Resolve-Path $dest).Path)" -ForegroundColor Green
} else {
    Write-Host "Build failed. If SSL errors appear, use GitHub Actions APK instead." -ForegroundColor Red
    exit 1
}
