#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Clone Flutter stable branch from official repository
echo "Downloading Flutter..."
git clone https://github.com -b stable --depth 1

# Add Flutter to the system path
export PATH="$PATH:$PATH_TO_FLUTTER/flutter/bin"

# Upgrade and run doctor to ensure everything is ready
flutter doctor

# Enable web support and build the project
echo "Building Flutter Web App..."
flutter config --enable-web
flutter build web --release
