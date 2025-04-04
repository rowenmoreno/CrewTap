import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crew_link/screens/connect/connect_screen.dart';
import 'package:crew_link/screens/connect/tabs/my_qr_tab.dart';
import 'package:crew_link/screens/connect/tabs/scan_tab.dart';
import 'package:crew_link/screens/connect/tabs/tap_tab.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks
@GenerateMocks([SupabaseClient, User])
import 'connect_screen_test.mocks.dart';

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockUser mockUser;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockUser = MockUser();
    
    // Setup mock user
    when(mockUser.id).thenReturn('test-user-id');
    when(mockUser.email).thenReturn('test@example.com');
    
    // Setup mock auth
    when(mockSupabaseClient.auth.currentUser).thenReturn(mockUser);
  });

  group('ConnectScreen', () {
    testWidgets('renders loading indicator initially', (WidgetTester tester) async {
      // Setup mock profile response
      when(mockSupabaseClient.from('profiles')).thenReturn(MockSupabaseQueryBuilder());
      
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectScreen(),
        ),
      );

      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when profile fetch fails', (WidgetTester tester) async {
      // Setup mock profile response to throw error
      when(mockSupabaseClient.from('profiles')).thenThrow(Exception('Profile not found'));
      
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectScreen(),
        ),
      );
      
      // Wait for error to be displayed
      await tester.pumpAndSettle();

      // Verify error message is shown
      expect(find.text('Error: Exception: Profile not found'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders tabs correctly when profile is loaded', (WidgetTester tester) async {
      // Setup mock profile response
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      when(mockSupabaseClient.from('profiles')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.select()).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.eq('id', 'test-user-id')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.single()).thenAnswer((_) async => {
        'id': 'test-user-id',
        'display_name': 'Test User',
        'position': 'Test Position',
      });
      
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectScreen(),
        ),
      );
      
      // Wait for profile to be loaded
      await tester.pumpAndSettle();

      // Verify tabs are rendered
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('My QR'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Tap'), findsOneWidget);
      
      // Verify tab content
      expect(find.byType(MyQRTab), findsOneWidget);
      expect(find.byType(ScanTab), findsOneWidget);
      expect(find.byType(TapTab), findsOneWidget);
    });

    testWidgets('switches between tabs correctly', (WidgetTester tester) async {
      // Setup mock profile response
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      when(mockSupabaseClient.from('profiles')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.select()).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.eq('id', 'test-user-id')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.single()).thenAnswer((_) async => {
        'id': 'test-user-id',
        'display_name': 'Test User',
        'position': 'Test Position',
      });
      
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectScreen(),
        ),
      );
      
      // Wait for profile to be loaded
      await tester.pumpAndSettle();

      // Verify initial tab is My QR
      expect(find.byType(MyQRTab), findsOneWidget);
      expect(find.byType(ScanTab), findsNothing);
      expect(find.byType(TapTab), findsNothing);

      // Tap on Scan tab
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      // Verify Scan tab is shown
      expect(find.byType(MyQRTab), findsNothing);
      expect(find.byType(ScanTab), findsOneWidget);
      expect(find.byType(TapTab), findsNothing);

      // Tap on Tap tab
      await tester.tap(find.text('Tap'));
      await tester.pumpAndSettle();

      // Verify Tap tab is shown
      expect(find.byType(MyQRTab), findsNothing);
      expect(find.byType(ScanTab), findsNothing);
      expect(find.byType(TapTab), findsOneWidget);
    });
  });

  group('MyQRTab', () {
    testWidgets('renders QR code with correct data', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MyQRTab(
            userId: 'test-user-id',
            displayName: 'Test User',
            position: 'Test Position',
          ),
        ),
      );

      // Verify QR code is rendered
      expect(find.byType(QrImageView), findsOneWidget);
      
      // Verify user info is displayed
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('Test Position'), findsOneWidget);
    });
  });

  group('ScanTab', () {
    testWidgets('renders camera view', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanTab(),
        ),
      );

      // Verify camera view is rendered
      expect(find.byType(MobileScanner), findsOneWidget);
    });
  });

  group('TapTab', () {
    testWidgets('renders NFC interface', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TapTab(
            userId: 'test-user-id',
            displayName: 'Test User',
            position: 'Test Position',
          ),
        ),
      );

      // Verify NFC interface is rendered
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('Test Position'), findsOneWidget);
      expect(find.text('Start NFC Connection'), findsOneWidget);
    });
  });
}

// Mock class for SupabaseQueryBuilder
class MockSupabaseQueryBuilder extends Mock {
  MockSupabaseQueryBuilder select() => this;
  MockSupabaseQueryBuilder eq(String column, dynamic value) => this;
  Future<Map<String, dynamic>> single() async => {};
} 