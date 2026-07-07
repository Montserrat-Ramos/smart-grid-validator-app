#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.38.3}"
SDK_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if [ ! -d "$HOME/flutter" ]; then
  curl -L "$SDK_URL" -o /tmp/flutter.tar.xz
  tar -xf /tmp/flutter.tar.xz -C "$HOME"
fi

export PATH="$HOME/flutter/bin:$PATH"
flutter config --enable-web
flutter pub get
flutter build web --release --dart-define="API_BASE_URL=${API_BASE_URL}"
