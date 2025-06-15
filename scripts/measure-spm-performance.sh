#!/bin/bash

# measure-spm-performance.sh
# Measures Swift Package Manager resolution and build performance

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BENCHMARKS_DIR="$PROJECT_ROOT/.benchmarks"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Performance thresholds (in seconds)
PACKAGE_RESOLVE_TARGET=1.0
PACKAGE_RESOLVE_WARNING=3.0
PACKAGE_RESOLVE_CRITICAL=10.0

# Ensure benchmarks directory exists
mkdir -p "$BENCHMARKS_DIR"

# Parse command line arguments
VERBOSE=false
COLLECT_ONLY=false
COMPARE_BASELINE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --collect-only)
            COLLECT_ONLY=true
            shift
            ;;
        --compare-baseline)
            COMPARE_BASELINE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --verbose          Enable verbose output"
            echo "  --collect-only     Only collect metrics (no reporting)"
            echo "  --compare-baseline Compare against baseline measurements"
            echo "  --help             Show this help message"
            echo ""
            echo "Measures Swift Package Manager performance including:"
            echo "  - Package resolution time"
            echo "  - Dependency fetching time"
            echo "  - Cache effectiveness"
            echo "  - Build preparation time"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to log with timestamp
log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[$(date -u +"%H:%M:%S")] $*" >&2
    fi
}

# Function to measure execution time
measure_time() {
    local description="$1"
    shift
    
    log "Measuring: $description"
    
    local start_time
    start_time=$(date +%s.%N)
    
    # Execute command and capture output/exit code
    local output
    local exit_code=0
    output=$(eval "$@" 2>&1) || exit_code=$?
    
    local end_time
    end_time=$(date +%s.%N)
    
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l)
    
    log "Completed: $description in ${duration}s"
    
    # Return duration and exit code
    echo "$duration"
    return $exit_code
}

# Function to check cache state
check_cache_state() {
    local cache_info="{}"
    
    if [[ -d ".build/repositories" ]]; then
        local repo_count
        repo_count=$(find .build/repositories -maxdepth 1 -type d | wc -l)
        cache_info=$(echo "$cache_info" | jq --arg count "$((repo_count - 1))" '.repositories_cached = ($count | tonumber)')
    else
        cache_info=$(echo "$cache_info" | jq '.repositories_cached = 0')
    fi
    
    if [[ -f ".build/workspace-state.json" ]]; then
        cache_info=$(echo "$cache_info" | jq '.workspace_state_exists = true')
    else
        cache_info=$(echo "$cache_info" | jq '.workspace_state_exists = false')
    fi
    
    if [[ -f ".build/manifest.db" ]]; then
        cache_info=$(echo "$cache_info" | jq '.manifest_db_exists = true')
    else
        cache_info=$(echo "$cache_info" | jq '.manifest_db_exists = false')
    fi
    
    echo "$cache_info"
}

# Function to clear SPM cache for cold measurements
clear_spm_cache() {
    log "Clearing SPM cache for cold measurement"
    rm -rf .build/repositories
    rm -rf .build/artifacts  
    rm -f .build/workspace-state.json
    rm -f .build/manifest.db
    rm -f .build/dependencies-state.json
    rm -rf ~/.cache/org.swift.swiftpm 2>/dev/null || true
}

# Function to measure package resolution performance
measure_package_resolution() {
    local measurement_type="$1" # "cold" or "warm"
    local results="{}"
    
    log "Starting $measurement_type package resolution measurement"
    
    # Check initial cache state
    local initial_cache
    initial_cache=$(check_cache_state)
    results=$(echo "$results" | jq --argjson cache "$initial_cache" '.initial_cache = $cache')
    
    if [[ "$measurement_type" == "cold" ]]; then
        clear_spm_cache
    fi
    
    # Measure package resolution
    local resolve_time
    resolve_time=$(measure_time "Package resolution ($measurement_type)" "swift package resolve")
    results=$(echo "$results" | jq --arg time "$resolve_time" '.package_resolve_time = ($time | tonumber)')
    
    # Check final cache state
    local final_cache
    final_cache=$(check_cache_state)
    results=$(echo "$results" | jq --argjson cache "$final_cache" '.final_cache = $cache')
    
    # Measure dependency info generation
    local deps_time
    deps_time=$(measure_time "Dependency info generation" "swift package show-dependencies --format json > /dev/null")
    results=$(echo "$results" | jq --arg time "$deps_time" '.dependency_info_time = ($time | tonumber)')
    
    # Calculate cache effectiveness
    local cache_effective=false
    if [[ "$measurement_type" == "warm" ]] && (( $(echo "$resolve_time < 1.0" | bc -l) )); then
        cache_effective=true
    fi
    results=$(echo "$results" | jq --arg effective "$cache_effective" '.cache_effective = ($effective == "true")')
    
    echo "$results"
}

# Function to measure build preparation performance
measure_build_preparation() {
    log "Measuring build preparation performance"
    
    local results="{}"
    
    # Measure package resolution + build preparation
    local prep_time
    prep_time=$(measure_time "Build preparation" "swift build --build-tests --dry-run")
    results=$(echo "$results" | jq --arg time "$prep_time" '.build_preparation_time = ($time | tonumber)')
    
    echo "$results"
}

# Function to analyze performance against baselines
analyze_performance() {
    local measurements="$1"
    local analysis="{}"
    
    # Extract key metrics
    local cold_resolve_time
    cold_resolve_time=$(echo "$measurements" | jq -r '.cold_measurement.package_resolve_time')
    
    local warm_resolve_time  
    warm_resolve_time=$(echo "$measurements" | jq -r '.warm_measurement.package_resolve_time')
    
    # Analyze package resolution performance
    local resolve_status="good"
    if (( $(echo "$cold_resolve_time > $PACKAGE_RESOLVE_WARNING" | bc -l) )); then
        resolve_status="warning"
    fi
    if (( $(echo "$cold_resolve_time > $PACKAGE_RESOLVE_CRITICAL" | bc -l) )); then
        resolve_status="critical"
    fi
    
    analysis=$(echo "$analysis" | jq --arg status "$resolve_status" '.package_resolution_status = $status')
    
    # Calculate cache speedup
    local cache_speedup=1.0
    if (( $(echo "$warm_resolve_time > 0" | bc -l) )); then
        cache_speedup=$(echo "$cold_resolve_time / $warm_resolve_time" | bc -l)
    fi
    analysis=$(echo "$analysis" | jq --arg speedup "$cache_speedup" '.cache_speedup = ($speedup | tonumber)')
    
    # Generate recommendations
    local recommendations='[]'
    
    if [[ "$resolve_status" != "good" ]]; then
        recommendations=$(echo "$recommendations" | jq '. + ["Consider dependency count optimization"]')
    fi
    
    if (( $(echo "$cache_speedup < 2.0" | bc -l) )); then
        recommendations=$(echo "$recommendations" | jq '. + ["Cache effectiveness could be improved"]')
    fi
    
    analysis=$(echo "$analysis" | jq --argjson recs "$recommendations" '.recommendations = $recs')
    
    echo "$analysis"
}

# Function to save measurements
save_measurements() {
    local measurements="$1"
    local filename="spm-performance-$TIMESTAMP.json"
    local filepath="$BENCHMARKS_DIR/$filename"
    
    # Add metadata
    local enriched_measurements
    enriched_measurements=$(echo "$measurements" | jq --arg ts "$TIMESTAMP" --arg pwd "$PWD" '
        .metadata = {
            timestamp: $ts,
            working_directory: $pwd,
            swift_version: "unknown",
            platform: "unknown"
        }
    ')
    
    # Add Swift version if available
    if command -v swift &> /dev/null; then
        local swift_version
        swift_version=$(swift --version 2>&1 | head -1 | sed 's/.*Swift version \([0-9.]*\).*/\1/')
        enriched_measurements=$(echo "$enriched_measurements" | jq --arg version "$swift_version" '.metadata.swift_version = $version')
    fi
    
    # Add platform info
    local platform
    platform=$(uname -s)-$(uname -m)
    enriched_measurements=$(echo "$enriched_measurements" | jq --arg platform "$platform" '.metadata.platform = $platform')
    
    echo "$enriched_measurements" > "$filepath"
    log "Measurements saved to: $filepath"
    
    # Update latest symlink
    local latest_link="$BENCHMARKS_DIR/spm-performance-latest.json"
    ln -sf "$filename" "$latest_link"
    log "Latest measurements symlink updated: $latest_link"
}

# Function to generate performance report
generate_report() {
    local measurements="$1"
    local analysis="$2"
    
    echo "## 🚀 Swift Package Manager Performance Report"
    echo ""
    echo "**Generated:** $TIMESTAMP"
    echo ""
    
    # Package Resolution Performance
    echo "### 📦 Package Resolution Performance"
    echo ""
    local cold_time
    cold_time=$(echo "$measurements" | jq -r '.cold_measurement.package_resolve_time')
    local warm_time
    warm_time=$(echo "$measurements" | jq -r '.warm_measurement.package_resolve_time')
    
    # Debug output
    if [[ "$VERBOSE" == "true" ]]; then
        log "DEBUG: cold_time='$cold_time', warm_time='$warm_time'"
    fi
    
    # Validate numeric values before printf
    if [[ "$cold_time" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        printf -- "- **Cold Resolution:** %.3fs\n" "$cold_time"
    else
        echo "- **Cold Resolution:** ${cold_time}s (invalid numeric value)"
    fi
    
    if [[ "$warm_time" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        printf -- "- **Warm Resolution:** %.3fs\n" "$warm_time"
    else
        echo "- **Warm Resolution:** ${warm_time}s (invalid numeric value)"
    fi
    
    local cache_speedup
    cache_speedup=$(echo "$analysis" | jq -r '.cache_speedup')
    
    if [[ "$cache_speedup" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        printf -- "- **Cache Speedup:** %.1fx\n" "$cache_speedup"
    else
        echo "- **Cache Speedup:** ${cache_speedup}x (invalid numeric value)"
    fi
    echo ""
    
    # Performance Status
    local status
    status=$(echo "$analysis" | jq -r '.package_resolution_status')
    case "$status" in
        "good")
            echo "✅ **Status:** Good performance"
            ;;
        "warning")
            echo "⚠️ **Status:** Performance warning"
            ;;
        "critical")
            echo "🔴 **Status:** Critical performance issue"
            ;;
    esac
    echo ""
    
    # Cache Analysis
    echo "### 💾 Cache Analysis"
    echo ""
    local warm_cache_effective
    warm_cache_effective=$(echo "$measurements" | jq -r '.warm_measurement.cache_effective')
    if [[ "$warm_cache_effective" == "true" ]]; then
        echo "✅ **Cache Effective:** Working properly"
    else
        echo "⚠️ **Cache Effective:** May need optimization"
    fi
    
    local repos_cached
    repos_cached=$(echo "$measurements" | jq -r '.warm_measurement.final_cache.repositories_cached')
    echo "- **Repositories Cached:** $repos_cached"
    echo ""
    
    # Build Preparation
    if echo "$measurements" | jq -e '.build_preparation' > /dev/null; then
        echo "### 🏗️ Build Preparation Performance"
        echo ""
        local prep_time
        prep_time=$(echo "$measurements" | jq -r '.build_preparation.build_preparation_time')
        printf -- "- **Preparation Time:** %.3fs\n" "$prep_time"
        echo ""
    fi
    
    # Recommendations
    local recommendations
    recommendations=$(echo "$analysis" | jq -r '.recommendations[]?' 2>/dev/null || true)
    if [[ -n "$recommendations" ]]; then
        echo "### 💡 Recommendations"
        echo ""
        while IFS= read -r recommendation; do
            echo "- $recommendation"
        done <<< "$recommendations"
        echo ""
    fi
    
    # Performance Thresholds
    echo "### ⚡ Performance Thresholds"
    echo ""
    printf -- "- **Target:** < %.1fs\n" "$PACKAGE_RESOLVE_TARGET"
    printf -- "- **Warning:** < %.1fs\n" "$PACKAGE_RESOLVE_WARNING"
    printf -- "- **Critical:** < %.1fs\n" "$PACKAGE_RESOLVE_CRITICAL"
    echo ""
}

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    log "Starting SPM performance measurement"
    log "Project root: $PROJECT_ROOT"
    
    # Initialize measurement results
    local all_measurements="{}"
    
    # Install bc for numerical calculations if not available
    if ! command -v bc &> /dev/null && command -v brew &> /dev/null; then
        log "Installing bc for numerical calculations"
        brew install bc >/dev/null 2>&1 || true
    fi
    
    # Install jq for JSON processing if not available
    if ! command -v jq &> /dev/null && command -v brew &> /dev/null; then
        log "Installing jq for JSON processing"
        brew install jq >/dev/null 2>&1 || true
    fi
    
    # Measure cold performance (no cache)
    local cold_measurement
    cold_measurement=$(measure_package_resolution "cold")
    all_measurements=$(echo "$all_measurements" | jq --argjson measurement "$cold_measurement" '.cold_measurement = $measurement')
    
    # Measure warm performance (with cache)
    local warm_measurement
    warm_measurement=$(measure_package_resolution "warm")
    all_measurements=$(echo "$all_measurements" | jq --argjson measurement "$warm_measurement" '.warm_measurement = $measurement')
    
    # Measure build preparation performance
    local build_prep
    build_prep=$(measure_build_preparation)
    all_measurements=$(echo "$all_measurements" | jq --argjson prep "$build_prep" '.build_preparation = $prep')
    
    # Save measurements
    save_measurements "$all_measurements"
    
    # Exit early if collect-only mode
    if [[ "$COLLECT_ONLY" == "true" ]]; then
        log "Collection complete (collect-only mode)"
        return 0
    fi
    
    # Analyze performance
    local performance_analysis
    performance_analysis=$(analyze_performance "$all_measurements")
    
    # Generate and display report
    generate_report "$all_measurements" "$performance_analysis"
    
    log "SPM performance measurement complete"
}

# Install dependencies and run main function
main "$@"