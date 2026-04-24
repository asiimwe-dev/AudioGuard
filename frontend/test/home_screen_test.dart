import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioguard_mobile/screens/home_screen.dart';
import 'package:audioguard_mobile/theme/app_theme.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('HomeScreen renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            home: const HomeScreen(),
          ),
        ),
      );

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('HomeScreen AppBar has title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            home: const HomeScreen(),
          ),
        ),
      );

      expect(find.text('AudioGuard'), findsWidgets);
    });

    testWidgets('HomeScreen displays mode selector', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            home: const HomeScreen(),
          ),
        ),
      );

      expect(find.byType(SegmentedButton), findsWidgets);
    });

    testWidgets('HomeScreen has action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            home: const HomeScreen(),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('HomeScreen displays recent operations section', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            home: const HomeScreen(),
          ),
        ),
      );

      expect(find.text('Recent Operations'), findsOneWidget);
    });
  });
}
