# CrewTap

A Flutter application for connecting with crew members using QR codes and NFC technology.

## Features

- QR Code Generation and Sharing
- QR Code Scanning
- NFC-based Connection
- Modern Material Design UI
- Tab-based Navigation

## Getting Started

### Prerequisites

- Flutter SDK
- Android Studio / VS Code
- Android Emulator or iOS Simulator
- For NFC features: Physical device with NFC capability

### Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/crew_link.git
```

2. Navigate to the project directory
```bash
cd crew_link
```

3. Install dependencies
```bash
flutter pub get
```

4. Run the app
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart
├── screens/
│   ├── connect/
│   │   ├── connect_screen.dart
│   │   └── tabs/
│   │       ├── my_qr_tab.dart
│   │       ├── scan_tab.dart
│   │       └── tap_tab.dart
│   ├── home_screen.dart
│   ├── profile_screen.dart
│   └── groups_screen.dart
```

## Dependencies

- qr_flutter: ^4.1.0
- mobile_scanner: ^3.5.6
- nfc_manager: ^3.3.0

## Contributing

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
