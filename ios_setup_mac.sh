#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting iOS setup process...${NC}"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}This script must be run on macOS${NC}"
    exit 1
fi

# Check if Xcode is installed
if ! xcode-select -p &> /dev/null; then
    echo -e "${RED}Xcode is not installed. Please install Xcode first.${NC}"
    echo -e "${YELLOW}You can install it from the Mac App Store${NC}"
    exit 1
fi

# Check if Xcode command line tools are installed
if ! xcode-select -p &> /dev/null; then
    echo -e "${YELLOW}Installing Xcode Command Line Tools...${NC}"
    xcode-select --install
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Flutter is not installed. Please install Flutter first.${NC}"
    echo -e "${YELLOW}Visit https://flutter.dev/docs/get-started/install/macos for installation instructions${NC}"
    exit 1
fi

# Check if Ruby is installed (required for CocoaPods)
if ! command -v ruby &> /dev/null; then
    echo -e "${RED}Ruby is not installed. Please install Ruby first.${NC}"
    echo -e "${YELLOW}You can install it using Homebrew: brew install ruby${NC}"
    exit 1
fi

# Check if CocoaPods is installed
if ! command -v pod &> /dev/null; then
    echo -e "${YELLOW}CocoaPods is not installed. Installing CocoaPods...${NC}"
    sudo gem install cocoapods
fi

# Get Flutter packages
echo -e "${YELLOW}Getting Flutter packages...${NC}"
flutter clean
flutter pub get
flutter build ios

# Navigate to iOS directory
cd ios

# Clean CocoaPods cache if needed
echo -e "${YELLOW}Cleaning CocoaPods cache...${NC}"
pod cache clean --all

# Install CocoaPods dependencies
echo -e "${YELLOW}Installing CocoaPods dependencies...${NC}"
pod install

# Open Xcode workspace
echo -e "${YELLOW}Opening Xcode workspace...${NC}"
open Runner.xcworkspace

echo -e "${GREEN}iOS setup completed!${NC}"

# Return to project root
cd .. 