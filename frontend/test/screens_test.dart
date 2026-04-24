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
            theme: AppTheme.lightTheme(),
            home: const EncodeScreen(),
          ),
        ),
      );

      expect(find.byType(EncodeScreen), findsOneWidget);
      expect(find.text('Encode Watermark'), findsOneWidget);
    });

    testWidgets('DecodeScreen renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const DecodeScreen(),
          ),
        ),
      );

      expect(find.byType(DecodeScreen), findsOneWidget);
      expect(find.text('Decode Watermark'), findsOneWidget);
    });

    testWidgets('VerifyScreen renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const VerifyScreen(),
          ),
        ),
      );

      expect(find.byType(VerifyScreen), findsOneWidget);
      expect(find.text('Verify Watermark'), findsOneWidget);
    });

    testWidgets('AnalyzeScreen renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
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
            theme: AppTheme.lightTheme(),
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
            theme: AppTheme.lightTheme(),
            home: const EncodeScreen(),
          ),
        ),
      );

      expect(find.text('No audio file selected'), findsOneWidget);
    });

    testWidgets('DecodeScreen shows empty state without file',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const DecodeScreen(),
          ),
        ),
      );

      expect(find.text('No audio file selected'), findsOneWidget);
    });

    testWidgets('VerifyScreen shows empty state without file',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const VerifyScreen(),
          ),
        ),
      );

      expect(find.text('No audio file selected'), findsOneWidget);
    });

    testWidgets('AnalyzeScreen shows empty state without file',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const AnalyzeScreen(),
          ),
        ),
      );

      expect(find.text('No audio file selected'), findsOneWidget);
    });
  });

  group('SettingsScreen Widget Tests', () {
    testWidgets('SettingsScreen has all sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );

      expect(find.text('API Configuration'), findsOneWidget);
      expect(find.text('Processing Mode'), findsOneWidget);
      expect(find.text('General Settings'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('SettingsScreen API URL field is present',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );

      expect(find.text('API Base URL'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('SettingsScreen has toggle switches',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );

      expect(find.byType(SwitchListTile), findsWidgets);
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
              theme: AppTheme.lightTheme(),
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
