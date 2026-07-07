$ErrorActionPreference = 'Stop'

Write-Host 'Configurando Smart Grid Validator para Web, Android y Windows...' -ForegroundColor Cyan

flutter config --enable-web --enable-windows-desktop
flutter create . `
  --project-name smart_grid_validator `
  --org mx.edu.upchiapas `
  --platforms android,windows

$manifest = 'android/app/src/main/AndroidManifest.xml'
if (Test-Path $manifest) {
  $content = Get-Content $manifest -Raw
  $manifestTag = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
  if ($content -notmatch 'android.permission.INTERNET') {
    $permission = '    <uses-permission android:name="android.permission.INTERNET" />'
    $content = $content.Replace($manifestTag, $manifestTag + "`r`n" + $permission)
  }
  if ($content -notmatch 'usesCleartextTraffic') {
    $applicationTag = '<application'
    $replacement = '<application' + "`r`n" + '        android:usesCleartextTraffic="true"'
    $content = $content.Replace($applicationTag, $replacement)
  }
  $content = $content.Replace('android:label="smart_grid_validator"', 'android:label="Smart Grid Validator"')
  Set-Content -Path $manifest -Value $content -Encoding UTF8
}


# Identidad visual Android.
$androidIconRoot = 'assets/platform_icons/android'
if (Test-Path $androidIconRoot) {
  Get-ChildItem $androidIconRoot -Directory | ForEach-Object {
    $destination = Join-Path 'android/app/src/main/res' $_.Name
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item (Join-Path $_.FullName 'ic_launcher.png') (Join-Path $destination 'ic_launcher.png') -Force
  }
}

# Identidad visual y título Windows.
$windowsIcon = 'assets/platform_icons/windows/app_icon.ico'
if ((Test-Path $windowsIcon) -and (Test-Path 'windows/runner/resources')) {
  Copy-Item $windowsIcon 'windows/runner/resources/app_icon.ico' -Force
}
$windowsMain = 'windows/runner/main.cpp'
if (Test-Path $windowsMain) {
  $windowsContent = Get-Content $windowsMain -Raw
  $windowsContent = $windowsContent.Replace('smart_grid_validator', 'Smart Grid Validator')
  Set-Content -Path $windowsMain -Value $windowsContent -Encoding UTF8
}

flutter pub get

Write-Host 'Plataformas creadas correctamente.' -ForegroundColor Green
Write-Host 'Ejecuta: flutter devices'
Write-Host 'Web:     flutter run -d chrome --web-port=8080'
Write-Host 'Android: flutter run -d <ID_DISPOSITIVO>'
Write-Host 'Windows: flutter run -d windows'
