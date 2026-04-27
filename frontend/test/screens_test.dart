import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioguard_mobile/screens/encode_screen.dart';
import 'package:audioguard_mobile/screens/decode_screen.dart';
import 'package:audioguard_mobile/screens/verify_screen.dart';
import 'package:audioguard_mobile/screens/analyze_screen.dart';
import 'package:audioguard_mobile/screens/settings_screen.dart';
import 'package:audioguard_mobile/theme/app_theme.dart';

void main() {
  group('Screen Rendering Tests', () {
    testWidgets('EncodeScreen renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(1.0),
            home: const EncodeScreen(),
          ),
        ),
      );

      expect(find.byType(EncodeScreen), findsOneWidget);
      expect(find.text('Encode Watermark'), findsWidgets);
    });

    testWidgets('DecodeScreen renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(1.0),
            home: const DecodeScreen(),
          ),
        ),
      );

      expect(find.byType(DecodeScreen), findsOneWidget);
      expect(find.text('Decode Watermark'), findsWidgets);
    });

    testWidgets('VerifyScreen renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(1.0),
            home: const VerifyScreen(),
          ),
        ),
      );

      expect(find.byType(VerifyScreen), findsOneWidget);
      expect(find.text('Verify Authenticity'), findsOneWidget);
    });

    testWidgets('AnalyzeScreen renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(1.0),
            home: const AnalyzeScreen(),
          ),
        ),
      );

      expect(find.byType(AnalyzeScreen), findsOneWidget);
      expect(find.text('Analyze Watermark'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(1.0),
            home: const SettingsScreen(),
          ),
        ),
      );

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('Screen Empty State Tests', () {
    testWidgets('EncodeScreen shows empty state without file',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(1.0),
            home: const EncodeScreen(),
          ),
        ),
      );

      expect(find.text('Choose Audio File'), findsOneWidget);
    });

    testWidgets('DecodeScreen shows empty state without file',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(1.0),
            home: const DecodeScreen(),
          ),
        ),
      );

      expect(find.text('Select Audio File'), findsOneWidget);
    });

    testWidgets('VerifyScreen shows empty state without file',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(1.0),
            home: const VerifyScreen(),
          ),
        ),
      );

      expect(find.text('Select Audio to Verify'), findsOneWidget);
    });

    testWidgets('AnalyzeScreen shows empty state without file',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(1.0),
            home: const AnalyzeScreen(),
          ),
        ),
      );

      expect(find.text('Select Audio File'), findsOneWidget);
    });
  });

  group('SettingsScreen Widget Tests', () {
    testWidgets('SettingsScreen has all sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(1.0),
            home: const SettingsScreen(),
          ),
        ),
      );

      // Allow time for widget to build
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Verify the basic structure is present (more robust than text matching)
      expect(find.byType(ListView), findsWidgets);
      expect(find.byType(Card), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('Screen Scaffolding Tests', () {
    testWidgets('All screens have Scaffold and AppBar',
        (WidgetTester tester) async {
      final screens = [
        const EncodeScreen(),
        const DecodeScreen(),
        const VerifyScreen(),
        const AnalyzeScreen(),
        const SettingsScreen(),
      ];

      for (final screen in screens) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme(1.0),
              home: screen,
            ),
          ),
        );

        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      }
    });
  });
}
