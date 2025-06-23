#!/bin/bash

# ExoManager Build and Run Script
# This script builds the ExoManager app and provides options to run it

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[BUILD]${NC} $1"
}

# Configuration
PROJECT_NAME="ExoManager"
APP_NAME="ExoManager"
PROJECT_FILE="ExoManager.xcodeproj"
SCHEME_NAME="ExoManager"
CONFIGURATION="Release"
PRODUCT_NAME="ExoManager.app"
BUILD_DIR="build"
DIST_DIR="dist"
SCRIPTS_DIR="scripts"
DMG_NAME="${PROJECT_NAME}.dmg"

# Function to launch the app
launch_app() {
    print_header "ExoManager Launcher"
    
    # Check if app exists
    if [ ! -d "$APP_PATH" ]; then
        print_error "ExoManager not found in common locations:"
        for path in "${APP_PATHS[@]}"; do
            echo "  - $path"
        done
        print_status "Please build the app first using: ./build.sh --install"
        exit 1
    fi
    
    print_status "Found ExoManager at: $APP_PATH"
    
    # Check if scripts are in the app bundle
    if [ -d "$APP_PATH/Contents/Resources/scripts" ]; then
        print_status "Scripts found in app bundle:"
        ls -la "$APP_PATH/Contents/Resources/scripts"
    else
        print_warning "No scripts found in app bundle"
    fi
    
    # Force quit the app if it's already running
    print_status "Checking if ExoManager is already running..."
    if pgrep -f "ExoManager" > /dev/null; then
        print_status "ExoManager is running, force quitting..."
        pkill -f "ExoManager"
        sleep 2
        
        # Double-check if it's still running
        if pgrep -f "ExoManager" > /dev/null; then
            print_warning "ExoManager still running, using force kill..."
            pkill -9 -f "ExoManager"
            sleep 1
        fi
        
        print_status "ExoManager stopped"
    else
        print_status "ExoManager is not running"
    fi
    
    print_status "Launching ExoManager with administrator privileges..."
    echo ""
    print_status "You will be prompted for your password to run with administrator privileges"
    echo ""
    
    # Launch with administrator privileges
    sudo open "$APP_PATH"
    
    if [ $? -eq 0 ]; then
        print_status "✓ ExoManager launched successfully!"
        print_status "The app should now be running with administrator privileges"
    else
        print_error "Failed to launch ExoManager"
        exit 1
    fi
}

# Function to copy scripts to app bundle
copy_scripts_to_bundle() {
    local app_bundle="$1"
    local resources_dir="$app_bundle/Contents/Resources"
    local scripts_dir="$resources_dir/scripts"
    
    print_status "Copying scripts to app bundle: $app_bundle"
    
    # Create scripts directory in app bundle
    mkdir -p "$scripts_dir"
    
    # Copy all scripts from scripts directory
    cp "$SCRIPTS_DIR"/*.sh "$scripts_dir/"
    cp "$SCRIPTS_DIR"/*.plist "$scripts_dir/" 2>/dev/null || true
    
    # Make scripts executable
    chmod +x "$scripts_dir"/*.sh
    
    print_status "✓ Scripts copied to app bundle"
    print_status "Scripts in bundle:"
    ls -la "$scripts_dir"
}

# Parse command line arguments
BUILD_ONLY=false
RUN_AFTER_BUILD=false
INSTALL_TO_APPLICATIONS=false
CREATE_DMG=false
LAUNCH_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --run)
            RUN_AFTER_BUILD=true
            shift
            ;;
        --install)
            INSTALL_TO_APPLICATIONS=true
            shift
            ;;
        --dmg)
            CREATE_DMG=true
            shift
            ;;
        --launch)
            LAUNCH_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --build-only     Build the app only (default)"
            echo "  --run            Build and run the app"
            echo "  --install        Build and install to /Applications/"
            echo "  --dmg            Create DMG installer"
            echo "  --launch         Launch existing app (no build)"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0               # Build only"
            echo "  $0 --run         # Build and run"
            echo "  $0 --install     # Build and install"
            echo "  $0 --dmg         # Build and create DMG"
            echo "  $0 --launch      # Launch existing app"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

print_header "ExoManager Build and Run Script"
echo ""

# Launch existing app if requested
if [ "$LAUNCH_ONLY" = true ]; then
    # Configuration for app search
    APP_NAME="ExoManager.app"
    APP_PATHS=(
        "/Applications/$APP_NAME"
        "./build/Build/Products/Release/$APP_NAME"
        "./build/$APP_NAME"
        "./ExoManager.app"
    )
    
    # Find the app
    APP_PATH=""
    for path in "${APP_PATHS[@]}"; do
        if [ -d "$path" ]; then
            APP_PATH="$path"
            break
        fi
    done
    
    launch_app
fi

# Check if we're in the right directory
if [ ! -d "$PROJECT_FILE" ]; then
    print_error "Project file $PROJECT_FILE not found. Please run this script from the exo-cluster-scripts directory."
    exit 1
fi

# Check Xcode installation
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode command line tools not found. Please install Xcode and command line tools."
    exit 1
fi

print_status "Xcode version: $(xcodebuild -version | head -1)"

# Check if scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
    print_error "Scripts directory not found at $SCRIPTS_DIR"
    exit 1
fi

print_status "Found scripts directory: $SCRIPTS_DIR"

# Clean previous builds
print_status "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
xcodebuild clean -project "$PROJECT_FILE" -scheme "$SCHEME_NAME" -configuration "$CONFIGURATION"

# Build the app
print_status "Building $PROJECT_NAME..."
xcodebuild build -project "$PROJECT_FILE" -scheme "$SCHEME_NAME" -configuration "$CONFIGURATION" -derivedDataPath "$BUILD_DIR"

# Check if build was successful
if [ $? -eq 0 ]; then
    print_status "✓ Build completed successfully!"
else
    print_error "Build failed!"
    exit 1
fi

# Find the built app
APP_PATH=$(find "$BUILD_DIR/Build/Products/Release" -name "$PRODUCT_NAME" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    print_error "Built app not found in $BUILD_DIR/Build/Products/Release"
    exit 1
fi

print_status "Built app found at: $APP_PATH"

# Copy scripts to app bundle
copy_scripts_to_bundle "$APP_PATH"

# After building the app, before copying to /Applications

APP_BUNDLE="$BUILD_DIR/Build/Products/Release/ExoManager.app"
APP_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/ExoManager"
INSTALL_PATH="/Applications/ExoManager.app"

# 1. Check if the built app contains the executable
if [ ! -f "$APP_EXECUTABLE" ]; then
    echo "[ERROR] Build failed: Executable missing at $APP_EXECUTABLE"
    exit 1
fi

# 2. Remove any existing app in /Applications
if [ -d "$INSTALL_PATH" ]; then
    echo "[INFO] Removing existing /Applications/ExoManager.app"
    sudo rm -rf "$INSTALL_PATH"
fi

# 3. Copy the app bundle to /Applications
echo "[INFO] Copying $APP_BUNDLE to $INSTALL_PATH"
sudo cp -R "$APP_BUNDLE" "$INSTALL_PATH"

# 4. Check and fix permissions
sudo chmod -R 755 "$INSTALL_PATH"

# 5. (Optional) Code sign for local development
if command -v codesign &> /dev/null; then
    echo "[INFO] Code signing app for local development"
    sudo codesign --force --deep --sign - "$INSTALL_PATH"
fi

# 6. Final check
if [ ! -f "$INSTALL_PATH/Contents/MacOS/ExoManager" ]; then
    echo "[ERROR] Install failed: Executable missing in /Applications/ExoManager.app"
    exit 1
fi

echo "[INFO] ExoManager installed successfully at $INSTALL_PATH"

# Create DMG if requested
if [ "$CREATE_DMG" = true ]; then
    print_status "Creating DMG installer..."
    mkdir -p "$DIST_DIR"
    dmg_name="$DIST_DIR/$APP_NAME.dmg"
    hdiutil create -volname "$APP_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "$dmg_name"
    print_status "✓ DMG created at $dmg_name"
else
    print_warning "create-dmg not found. Skipping DMG creation."
    print_status "You can install create-dmg with: brew install create-dmg"
fi

# Create a simple zip archive
print_status "Creating zip archive..."
mkdir -p "$DIST_DIR"
zip_file="$DIST_DIR/$APP_NAME.zip"
zip_file_abs="$PWD/$zip_file"

# Remove existing zip to avoid issues
rm -f "$zip_file_abs"

# Go to the directory containing the app bundle to get clean paths in the zip
cd "$(dirname "$APP_PATH")"

# Create the zip archive, preserving symlinks
zip -ry "$zip_file_abs" "$(basename "$APP_PATH")"

# Go back to the original directory
cd - > /dev/null

print_status "✓ Zip archive created at $zip_file"

# Display build results
print_header "Build completed successfully!"
echo ""
print_status "Build artifacts:"
echo "  - App: $APP_PATH"
if [ "$CREATE_DMG" = true ] && [ -f "$BUILD_DIR/$DMG_NAME" ]; then
    echo "  - DMG: $BUILD_DIR/$DMG_NAME"
fi
echo "  - ZIP: $BUILD_DIR/${PROJECT_NAME}.zip"
echo ""
print_status "Scripts included in app bundle:"
echo "  - install_exo_service.sh"
echo "  - uninstall_exo_service.sh"
echo "  - start_exo.sh"
echo "  - check_exo_status.sh"
echo "  - com.exolabs.exo.plist"

# Run the app if requested
if [ "$RUN_AFTER_BUILD" = true ]; then
    echo ""
    print_status "Launching ExoManager..."
    
    # Check if we should run with administrator privileges
    if [ "$INSTALL_TO_APPLICATIONS" = true ]; then
        print_status "Running installed app with administrator privileges..."
        sudo open "/Applications/$PRODUCT_NAME"
    else
        print_status "Running built app..."
        print_warning "Note: You may need administrator privileges to install exo services"
        print_status "To run with admin privileges: sudo open '$APP_PATH'"
        open "$APP_PATH"
    fi
fi

echo ""
print_status "Next steps:"
if [ "$INSTALL_TO_APPLICATIONS" = true ]; then
    echo "  - App is installed at /Applications/$PRODUCT_NAME"
    echo "  - Run with admin privileges: sudo open /Applications/$PRODUCT_NAME"
else
    echo "  - Install to Applications: $0 --install"
    echo "  - Run the app: $0 --run"
fi
echo "  - Create DMG installer: $0 --dmg"
echo ""
print_warning "Note: ExoManager requires administrator privileges to install and manage the exo service." 