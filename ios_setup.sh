#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting iOS setup process...${NC}"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Flutter is not installed. Please install Flutter first.${NC}"
    exit 1
fi

# Check if CocoaPods is installed
if ! command -v pod &> /dev/null; then
    echo -e "${YELLOW}CocoaPods is not installed. Installing CocoaPods...${NC}"
    sudo gem install cocoapods
fi

# Get Flutter packages
echo -e "${YELLOW}Getting Flutter packages...${NC}"
flutter pub get

# Navigate to iOS directory
cd ios

# Install CocoaPods dependencies
echo -e "${YELLOW}Installing CocoaPods dependencies...${NC}"
pod install

# Check if Runner.entitlements exists
if [ ! -f "Runner/Runner.entitlements" ]; then
    echo -e "${YELLOW}Creating Runner.entitlements file...${NC}"
    cat > Runner/Runner.entitlements << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.nfc.readersession.formats</key>
    <array>
        <string>NDEF</string>
        <string>TAG</string>
    </array>
</dict>
</plist>
EOL
fi

# Check if Info.plist has required NFC entries
if ! grep -q "com.apple.developer.nfc.readersession.felica.systemcodes" Runner/Info.plist; then
    echo -e "${YELLOW}Adding NFC configurations to Info.plist...${NC}"
    # Create a temporary file
    awk '
    /<key>com.apple.developer.nfc.readersession.formats<\/key>/ {
        print $0;
        print "    <array>";
        print "        <string>NDEF</string>";
        print "        <string>TAG</string>";
        print "    </array>";
        print "    <key>com.apple.developer.nfc.readersession.felica.systemcodes</key>";
        print "    <array>";
        print "        <string>*</string>";
        print "    </array>";
        print "    <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>";
        print "    <array>";
        print "        <string>*</string>";
        print "    </array>";
        next;
    }
    {print}' Runner/Info.plist > Runner/Info.plist.tmp
    mv Runner/Info.plist.tmp Runner/Info.plist
fi

echo -e "${GREEN}iOS setup completed!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Select the Runner target"
echo "3. Go to Signing & Capabilities"
echo "4. Add 'Near Field Communication Tag Reading' capability"
echo "5. Ensure your Apple Developer account has NFC capability enabled"
echo "6. Update your provisioning profile in the Apple Developer Portal"
echo "7. Download and install the new provisioning profile in Xcode"

# Return to project root
cd .. 