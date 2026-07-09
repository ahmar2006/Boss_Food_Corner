#!/bin/bash
set -e

# 1. Define where Flutter will be installed
export FLUTTER_HOME="$SIGN_OUT_DIR/flutter"
export PATH="$PATH:$FLUTTER_HOME/bin"

# 2. Clone Flutter WITHOUT the shallow depth constraint (--depth 1)
# This prevents the Git 128 error during internal version checks
echo "Downloading stable Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_HOME

# 3. Disable Flutter tracking & analytics to prevent unexpected terminal pauses
flutter config --no-analytics

# 4. Explicitly bypass Git version check crashes
git config --global --add safe.directory '*'

# 5. Build the web app
echo "Building Flutter Web application..."
flutter config --enable-web
flutter build web --release
