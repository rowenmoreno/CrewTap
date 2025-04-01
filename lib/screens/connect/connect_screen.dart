import 'package:flutter/material.dart';
import 'tabs/my_qr_tab.dart';
import 'tabs/scan_tab.dart';
import 'tabs/tap_tab.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isScanTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    final isScanTab = _tabController.index == 1;
    if (isScanTab != _isScanTab) {
      setState(() {
        _isScanTab = isScanTab;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code),
                  SizedBox(width: 8),
                  Text('My QR'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner),
                  SizedBox(width: 8),
                  Text('Scan'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tap_and_play),
                  SizedBox(width: 8),
                  Text('Tap'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const MyQRTab(),
          ScanTab(isActive: _isScanTab),
          const TapTab(),
        ],
      ),
    );
  }
} 