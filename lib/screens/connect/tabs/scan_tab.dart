import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanTab extends StatefulWidget {
  const ScanTab({super.key, required this.isActive});

  final bool isActive;

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  final MobileScannerController cameraController = MobileScannerController();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScanTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        cameraController.start();
      } else {
        cameraController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        MobileScanner(
          controller: cameraController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('QR Code found! Value: ${barcode.rawValue}'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          },
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.off ? Icons.flash_off : Icons.flash_on,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ),
      ],
    );
  }
} 