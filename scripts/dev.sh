#!/bin/bash

SCHEME="Whisky"
CONFIG="Debug"
SIGN_FLAGS="CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"
WATCH_DIRS="Whisky WhiskyKit WhiskyCmd WhiskyThumbnail"

build_and_run() {
  echo ""
  echo "==> Building..."
  # Kill previous instance
  pkill -x Whisky 2>/dev/null

  if xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" -destination 'platform=macOS' $SIGN_FLAGS build 2>&1 | xcbeautify; then
    APP_PATH=$(xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | head -1 | awk '{print $3}')/Whisky.app
    echo "==> Launching $APP_PATH"
    open "$APP_PATH"
    echo "==> Watching for changes... (Ctrl+C to stop)"
  else
    echo "==> Build failed. Watching for changes..."
  fi
}

# Initial build + launch
build_and_run

# Watch for Swift file changes and rebuild
fswatch -r -e ".*" -i "\\.swift$" -i "\\.xib$" -i "\\.storyboard$" -i "\\.xcassets" --batch-marker $WATCH_DIRS | while read; do
  build_and_run
done
