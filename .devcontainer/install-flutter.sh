#!/bin/bash
set -e

echo "=== Installazione Flutter ==="

# Installa dipendenze
sudo apt-get update -y
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa wget

# Download Flutter SDK stabile
cd /home/codespace
wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.4-stable.tar.xz
tar xf flutter_linux_3.27.4-stable.tar.xz
rm flutter_linux_3.27.4-stable.tar.xz

# Aggiungi al PATH
echo 'export PATH="$PATH:/home/codespace/flutter/bin"' >> /home/codespace/.bashrc
export PATH="$PATH:/home/codespace/flutter/bin"

# Abilita Flutter Web
flutter config --enable-web --no-analytics
flutter precache --web

# Crea il progetto Flutter se non esiste
if [ ! -f "pubspec.yaml" ]; then
  flutter create . --project-name restaurant_booking --platforms web
fi

echo "=== Flutter installato! ==="
flutter --version
