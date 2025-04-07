# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow

Write-Host "Starting iOS setup process..." -ForegroundColor $Yellow

# Check if Flutter is installed
try {
    $flutterVersion = flutter --version
    Write-Host "Flutter is installed." -ForegroundColor $Green
} catch {
    Write-Host "Flutter is not installed. Please install Flutter first." -ForegroundColor $Red
    exit 1
}

# Check if CocoaPods is installed
try {
    $podVersion = pod --version
    Write-Host "CocoaPods is installed." -ForegroundColor $Green
} catch {
    Write-Host "CocoaPods is not installed. Please install CocoaPods first." -ForegroundColor $Red
    Write-Host "You can install it by running: gem install cocoapods" -ForegroundColor $Yellow
    exit 1
}

# Get Flutter packages
Write-Host "Getting Flutter packages..." -ForegroundColor $Yellow
flutter pub get

# Navigate to iOS directory
Set-Location -Path "ios"

# Install CocoaPods dependencies
Write-Host "Installing CocoaPods dependencies..." -ForegroundColor $Yellow
pod install

# Check if Runner.entitlements exists
if (-not (Test-Path "Runner/Runner.entitlements")) {
    Write-Host "Creating Runner.entitlements file..." -ForegroundColor $Yellow
    @"
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
"@ | Out-File -FilePath "Runner/Runner.entitlements" -Encoding UTF8
}

# Check if Info.plist has required NFC entries
$infoPlistContent = Get-Content "Runner/Info.plist" -Raw
if (-not ($infoPlistContent -match "com.apple.developer.nfc.readersession.felica.systemcodes")) {
    Write-Host "Adding NFC configurations to Info.plist..." -ForegroundColor $Yellow
    
    # Create backup
    Copy-Item "Runner/Info.plist" "Runner/Info.plist.backup"
    
    # Add NFC configurations
    $nfcConfig = @"
    <key>com.apple.developer.nfc.readersession.formats</key>
    <array>
        <string>NDEF</string>
        <string>TAG</string>
    </array>
    <key>com.apple.developer.nfc.readersession.felica.systemcodes</key>
    <array>
        <string>*</string>
    </array>
    <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
    <array>
        <string>*</string>
    </array>
"@
    
    # Insert NFC config after the existing NFC formats entry
    $infoPlistContent = $infoPlistContent -replace "(<key>com.apple.developer.nfc.readersession.formats</key>.*?</array>)", "`$1`n$nfcConfig"
    $infoPlistContent | Out-File -FilePath "Runner/Info.plist" -Encoding UTF8
}

Write-Host "`niOS setup completed!" -ForegroundColor $Green
Write-Host "`nNext steps:" -ForegroundColor $Yellow
Write-Host "1. Open ios/Runner.xcworkspace in Xcode"
Write-Host "2. Select the Runner target"
Write-Host "3. Go to Signing & Capabilities"
Write-Host "4. Add 'Near Field Communication Tag Reading' capability"
Write-Host "5. Ensure your Apple Developer account has NFC capability enabled"
Write-Host "6. Update your provisioning profile in the Apple Developer Portal"
Write-Host "7. Download and install the new provisioning profile in Xcode"

# Return to project root
Set-Location -Path ".." 