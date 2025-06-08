#!/bin/bash

# Quick launch script - just relaunch the app without rebuilding

BUNDLE_ID="com.yourcompany.WorkoutTracker"
DEVICE_NAME="iPhone 16"

echo "🚀 Quick launching WorkoutTracker..."

# Find device
DEVICE_ID=$(xcrun simctl list devices | grep "    $DEVICE_NAME (" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')

if [ -z "$DEVICE_ID" ]; then
    echo "❌ Could not find device: $DEVICE_NAME"
    exit 1
fi

# Terminate and relaunch
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
sleep 0.5

if xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1; then
    echo "✅ App relaunched!"
    
    # Bring Simulator to front
    osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
else
    echo "❌ Failed to launch. Try './run.sh' to rebuild and install."
    exit 1
fi