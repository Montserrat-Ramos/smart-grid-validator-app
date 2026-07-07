#!/usr/bin/env bash
set -euo pipefail

flutter config --enable-web
flutter create . \
  --project-name smart_grid_validator \
  --org mx.edu.upchiapas \
  --platforms android,windows

python3 - <<'PY'
from pathlib import Path
path = Path('android/app/src/main/AndroidManifest.xml')
if path.exists():
    text = path.read_text(encoding='utf-8')
    marker = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
    if 'android.permission.INTERNET' not in text:
        text = text.replace(marker, marker + '\n    <uses-permission android:name="android.permission.INTERNET" />')
    if 'usesCleartextTraffic' not in text:
        text = text.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)
    path.write_text(text, encoding='utf-8')
PY


# Copy platform icons generated from the approved logo.
for density in mipmap-mdpi mipmap-hdpi mipmap-xhdpi mipmap-xxhdpi mipmap-xxxhdpi; do
  mkdir -p "android/app/src/main/res/$density"
  cp "assets/platform_icons/android/$density/ic_launcher.png" \
     "android/app/src/main/res/$density/ic_launcher.png"
done
if [ -d windows/runner/resources ]; then
  cp assets/platform_icons/windows/app_icon.ico windows/runner/resources/app_icon.ico
fi
python3 - <<'PY2'
from pathlib import Path
manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    text = manifest.read_text(encoding='utf-8')
    text = text.replace('android:label="smart_grid_validator"', 'android:label="Smart Grid Validator"')
    manifest.write_text(text, encoding='utf-8')
main = Path('windows/runner/main.cpp')
if main.exists():
    main.write_text(main.read_text(encoding='utf-8').replace('smart_grid_validator', 'Smart Grid Validator'), encoding='utf-8')
PY2

flutter pub get

echo "Plataformas creadas. Usa flutter devices para consultar los destinos disponibles."
