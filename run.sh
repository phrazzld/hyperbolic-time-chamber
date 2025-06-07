#!/bin/bash

# WorkoutTracker Development Script
# Builds and launches the app in iOS Simulator

set -e  # Exit on any error

# Configuration
PROJECT_NAME="WorkoutTracker"
SCHEME="WorkoutTracker"
BUNDLE_ID="com.yourcompany.WorkoutTracker"
DEFAULT_DEVICE="iPhone 16"
CONFIGURATION="Debug"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to find device ID by name
find_device_id() {
    local device_name="$1"
    xcrun simctl list devices | grep "    $device_name (" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/'
}

# Function to get device status
get_device_status() {
    local device_id="$1"
    xcrun simctl list devices | grep "$device_id" | sed -E 's/.*\(([^)]+)\)$/\1/'
}

# Function to boot simulator if needed
ensure_simulator_ready() {
    local device_name="$1"
    
    log_info "Finding $device_name simulator..."
    local device_id=$(find_device_id "$device_name")
    
    if [ -z "$device_id" ]; then
        log_error "Could not find $device_name simulator"
        log_info "Available devices:"
        xcrun simctl list devices | grep "iPhone"
        exit 1
    fi
    
    log_info "Found device ID: $device_id"
    
    local status=$(get_device_status "$device_id")
    log_info "Device status: $status"
    
    if [[ "$status" != *"Booted"* ]]; then
        log_info "Booting $device_name simulator..."
        xcrun simctl boot "$device_id" || {
            log_error "Failed to boot simulator"
            exit 1
        }
        log_success "Simulator booted successfully"
        
        # Wait a moment for simulator to fully boot
        sleep 3
    else
        log_success "Simulator already booted"
    fi
    
    echo "$device_id"
}

# Function to build the app
build_app() {
    local device_name="$1"
    
    log_info "Building $PROJECT_NAME for $device_name..."
    
    if [ "$2" = "--clean" ]; then
        log_info "Performing clean build..."
        local clean_action="clean"
    else
        local clean_action=""
    fi
    
    xcodebuild \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -sdk iphonesimulator \
        -destination "platform=iOS Simulator,name=$device_name" \
        $clean_action build || {
        log_error "Build failed"
        exit 1
    }
    
    log_success "Build completed successfully"
}

# Function to install app
install_app() {
    local device_id="$1"
    
    log_info "Installing $PROJECT_NAME..."
    
    # Find the app bundle path
    local app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "$PROJECT_NAME.app" -path "*Debug-iphonesimulator*" | head -1)
    
    if [ -z "$app_path" ]; then
        log_error "Could not find built app bundle"
        exit 1
    fi
    
    log_info "App bundle found at: $app_path"
    
    # Uninstall previous version if exists
    xcrun simctl uninstall "$device_id" "$BUNDLE_ID" 2>/dev/null || true
    
    # Install the app
    local install_output=$(xcrun simctl install "$device_id" "$app_path" 2>&1)
    local install_result=$?
    
    if [ $install_result -ne 0 ]; then
        log_error "Failed to install app: $install_output"
        exit 1
    fi
    
    log_success "App installed successfully"
}

# Function to launch app
launch_app() {
    local device_id="$1"
    
    log_info "Launching $PROJECT_NAME..."
    
    local launch_output=$(xcrun simctl launch "$device_id" "$BUNDLE_ID" 2>&1)
    local launch_result=$?
    
    if [ $launch_result -eq 0 ]; then
        local pid=$(echo "$launch_output" | sed 's/.*: //')
        log_success "App launched successfully (PID: $pid)"
    else
        log_error "Failed to launch app: $launch_output"
        exit 1
    fi
}

# Function to open Simulator app
open_simulator() {
    log_info "Opening Simulator app..."
    open -a Simulator
    sleep 2
    osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
    log_success "Simulator app opened"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [DEVICE_NAME]"
    echo ""
    echo "Options:"
    echo "  --clean         Perform clean build"
    echo "  --no-sim        Don't open Simulator app"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build and run on iPhone 16"
    echo "  $0 'iPhone 15 Pro'    # Build and run on iPhone 15 Pro"
    echo "  $0 --clean            # Clean build and run on iPhone 16"
}

# Main execution
main() {
    local device_name="$DEFAULT_DEVICE"
    local clean_build=false
    local open_sim=true
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                clean_build=true
                shift
                ;;
            --no-sim)
                open_sim=false
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                device_name="$1"
                shift
                ;;
        esac
    done
    
    log_info "Starting WorkoutTracker development workflow..."
    log_info "Target device: $device_name"
    
    # Check if we're in the right directory
    if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
        log_error "Not in the correct directory. Please run from project root."
        exit 1
    fi
    
    # Execute workflow
    local device_id=$(ensure_simulator_ready "$device_name")
    
    if [ "$clean_build" = true ]; then
        build_app "$device_name" "--clean"
    else
        build_app "$device_name"
    fi
    
    install_app "$device_id"
    launch_app "$device_id"
    
    if [ "$open_sim" = true ]; then
        open_simulator
    fi
    
    log_success "🎉 WorkoutTracker is now running on $device_name!"
    log_info "Use 'xcrun simctl list apps \"$device_name\"' to check app status"
}

# Run main function with all arguments
main "$@"