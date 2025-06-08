#!/bin/bash

# WorkoutTracker Development Script
# Fast, reliable build and deploy for iterative development

set -e

# Configuration
PROJECT_NAME="WorkoutTracker"
BUNDLE_ID="com.yourcompany.WorkoutTracker"
DEFAULT_DEVICE="iPhone 16"

# Parse arguments
DEVICE_NAME="$DEFAULT_DEVICE"
CLEAN_BUILD=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --device)
            DEVICE_NAME="$2"
            shift 2
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --clean         Clean build (slower but ensures fresh build)"
            echo "  --device NAME   Target device (default: iPhone 16)"
            echo "  --quiet         Minimal output"
            echo "  --help          Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                    # Quick rebuild and run"
            echo "  $0 --clean            # Clean build and run"
            echo "  $0 --device 'iPhone 15 Pro'  # Run on different device"
            exit 0
            ;;
        *)
            DEVICE_NAME="$1"
            shift
            ;;
    esac
done

# Logging functions
log() {
    if [ "$QUIET" != true ]; then
        echo "$1"
    fi
}

log_step() {
    if [ "$QUIET" != true ]; then
        echo "🔄 $1"
    fi
}

log_success() {
    echo "✅ $1"
}

log_error() {
    echo "❌ $1"
}

# Check if we're in the right directory
if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    log_error "Not in project directory. Please run from project root."
    exit 1
fi

if [ "$QUIET" != true ]; then
    echo "🏋️  WorkoutTracker Development Workflow"
    echo "Device: $DEVICE_NAME"
    echo "Clean: $([ "$CLEAN_BUILD" = true ] && echo "Yes" || echo "No")"
    echo ""
fi

# 1. Manage simulator
log_step "Managing simulator..."
xcrun simctl shutdown all 2>/dev/null || true
sleep 1

DEVICE_ID=$(xcrun simctl list devices | grep "    $DEVICE_NAME (" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')

if [ -z "$DEVICE_ID" ]; then
    log_error "Could not find device: $DEVICE_NAME"
    log "Available devices:"
    xcrun simctl list devices | grep "iPhone" | head -5
    exit 1
fi

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
log "Simulator ready: $DEVICE_ID"

# 2. Build
log_step "Building..."

if [ "$CLEAN_BUILD" = true ]; then
    # Clean derived data for this project
    find ~/Library/Developer/Xcode/DerivedData -name "${PROJECT_NAME}-*" -type d -exec rm -rf {} + 2>/dev/null || true
    CLEAN_ACTION="clean"
    log "Performing clean build..."
else
    CLEAN_ACTION=""
fi

BUILD_OUTPUT=$(mktemp)
if xcodebuild \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$PROJECT_NAME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,name=$DEVICE_NAME" \
    $CLEAN_ACTION build \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO > "$BUILD_OUTPUT" 2>&1; then
    log_success "Build completed"
else
    log_error "Build failed"
    if [ "$QUIET" != true ]; then
        echo "Build output:"
        tail -20 "$BUILD_OUTPUT"
    fi
    rm -f "$BUILD_OUTPUT"
    exit 1
fi
rm -f "$BUILD_OUTPUT"

# 3. Find app bundle
APP_BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData -name "${PROJECT_NAME}.app" -path "*Debug-iphonesimulator*" 2>/dev/null | head -1)

if [ -z "$APP_BUNDLE" ] || [ ! -d "$APP_BUNDLE" ]; then
    log_error "Could not find app bundle"
    exit 1
fi

log "App bundle: $(basename "$APP_BUNDLE")"

# 4. Install
log_step "Installing..."
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true

if xcrun simctl install "$DEVICE_ID" "$APP_BUNDLE" 2>/dev/null; then
    log_success "App installed"
else
    log_error "Failed to install app"
    exit 1
fi

# 5. Launch
log_step "Launching..."
if xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1; then
    log_success "App launched"
else
    log_error "Failed to launch app"
    exit 1
fi

# 6. Open Simulator
if ! pgrep -f "Simulator\.app" > /dev/null; then
    open -a Simulator
    sleep 1
fi
osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true

echo ""
log_success "🎉 WorkoutTracker is running on $DEVICE_NAME!"
if [ "$QUIET" != true ]; then
    echo "💡 Run './run.sh' for quick rebuilds, './run.sh --clean' for clean builds"
fi
echo ""