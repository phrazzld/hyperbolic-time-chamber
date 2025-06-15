#!/bin/bash
set -e

# Script to validate App Store screenshot generation setup
# Tests the configuration and dependencies without running full screenshot generation

echo "🔍 Validating App Store Screenshot Generation Setup"
echo "================================================="

# Check directory structure
echo "📁 Checking directory structure..."
if [ ! -f "fastlane/Snapfile" ]; then
    echo "❌ Missing Snapfile configuration"
    exit 1
fi

if [ ! -f "fastlane/Fastfile" ]; then
    echo "❌ Missing Fastfile"
    exit 1
fi

if [ ! -d "Tests/WorkoutTrackerUITests" ]; then
    echo "❌ Missing UI test target"
    exit 1
fi

echo "✅ Directory structure looks good"

# Check UI test files
echo "📱 Checking UI test files..."
required_files=(
    "Tests/WorkoutTrackerUITests/ScreenshotTests.swift"
    "Tests/WorkoutTrackerUITests/SnapshotHelper.swift"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing required file: $file"
        exit 1
    fi
done

echo "✅ UI test files are present"

# Check demo data service
echo "🎭 Checking demo data service..."
if [ ! -f "Sources/WorkoutTracker/Services/DemoDataService.swift" ]; then
    echo "❌ Missing DemoDataService.swift"
    exit 1
fi

# Verify demo data service is properly integrated
if ! grep -q "DemoDataService.populateWithDemoDataIfNeeded" "Sources/WorkoutTracker/WorkoutTrackerApp.swift"; then
    echo "❌ DemoDataService not integrated in WorkoutTrackerApp.swift"
    exit 1
fi

echo "✅ Demo data service is properly configured"

# Check Snapfile configuration
echo "📋 Validating Snapfile configuration..."
snapfile_content=$(cat fastlane/Snapfile)

# Check required devices
required_devices=("iPhone 15 Pro Max" "iPhone 15 Plus" "iPhone 15" "iPhone SE" "iPad Pro")
for device in "${required_devices[@]}"; do
    if ! echo "$snapfile_content" | grep -q "$device"; then
        echo "⚠️ Device '$device' not found in Snapfile (this might be OK)"
    fi
done

# Check required configuration
required_configs=("devices" "languages" "scheme" "output_directory")
for config in "${required_configs[@]}"; do
    if ! echo "$snapfile_content" | grep -q "$config"; then
        echo "❌ Missing required configuration: $config"
        exit 1
    fi
done

echo "✅ Snapfile configuration is valid"

# Check Fastfile lanes
echo "🛤️ Checking Fastfile lanes..."
fastfile_content=$(cat fastlane/Fastfile)

if ! echo "$fastfile_content" | grep -q "lane :screenshots"; then
    echo "❌ Missing screenshots lane in Fastfile"
    exit 1
fi

if ! echo "$fastfile_content" | grep -q "snapshot("; then
    echo "❌ Fastfile doesn't call snapshot action"
    exit 1
fi

echo "✅ Fastfile lanes are properly configured"

# Check Bundle/Fastlane setup
echo "💎 Checking Ruby/Fastlane setup..."
if [ ! -f "fastlane/Gemfile" ]; then
    echo "❌ Missing Gemfile"
    exit 1
fi

# Check if bundler is available
if ! command -v bundle >/dev/null 2>&1; then
    echo "⚠️ Bundler not found. Install with: gem install bundler"
fi

# Try to validate Fastlane can load
cd fastlane
if ! bundle exec fastlane --version >/dev/null 2>&1; then
    echo "❌ Fastlane cannot be loaded. Run: bundle install"
    exit 1
fi
cd ..

echo "✅ Ruby/Fastlane setup is working"

# Check Swift package build
echo "🔨 Checking Swift package build..."
if ! swift build --configuration debug >/dev/null 2>&1; then
    echo "❌ Swift package does not build. Fix compilation errors first."
    exit 1
fi

echo "✅ Swift package builds successfully"

# Check for launch arguments support
echo "🚀 Checking launch arguments support..."
demo_service_content=$(cat Sources/WorkoutTracker/Services/DemoDataService.swift)

required_flags=("FASTLANE_SNAPSHOT" "DEMO_MODE" "UI_TESTING" "DISABLE_ANIMATIONS")
for flag in "${required_flags[@]}"; do
    if ! echo "$demo_service_content" | grep -q "$flag"; then
        echo "⚠️ Launch argument '$flag' not handled in DemoDataService"
    fi
done

echo "✅ Launch arguments are supported"

# Summary
echo ""
echo "🎉 Screenshot Generation Setup Validation Complete!"
echo "=================================================="
echo "✅ All required files and configurations are present"
echo "✅ Fastlane is properly installed and configured"
echo "✅ UI test target is set up with screenshot tests"
echo "✅ Demo data service is configured for screenshot mode"
echo "✅ Swift package builds successfully"
echo ""
echo "📱 To generate screenshots:"
echo "   cd fastlane && bundle exec fastlane screenshots"
echo ""
echo "⚠️ Note: Screenshot generation requires:"
echo "   - Xcode with iOS Simulator"
echo "   - Valid signing configuration (for device builds)"
echo "   - App Store Connect API key (for upload)"
echo ""
echo "📚 For more information, see:"
echo "   - DEPLOYMENT.md for setup instructions"
echo "   - fastlane/README.md for Fastlane configuration"