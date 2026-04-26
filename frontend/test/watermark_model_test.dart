import 'package:flutter_test/flutter_test.dart';
import 'package:audioguard_mobile/providers/watermark_provider.dart';
import 'package:audioguard_mobile/utils/constants.dart';

void main() {
  group('WatermarkMode Tests', () {
    test('WatermarkMode has correct labels', () {
      expect(WatermarkMode.local.label, 'Local Processing');
      expect(WatermarkMode.cloud.label, 'Cloud Processing');
      expect(WatermarkMode.hybrid.label, 'Hybrid (Intelligent Fallback)');
    });

    test('WatermarkMode fromString works correctly', () {
      expect(WatermarkMode.fromString('local'), WatermarkMode.local);
      expect(WatermarkMode.fromString('cloud'), WatermarkMode.cloud);
      expect(WatermarkMode.fromString('hybrid'), WatermarkMode.hybrid);
    });

    test('WatermarkMode fromString with invalid string returns hybrid', () {
      expect(WatermarkMode.fromString('invalid'), WatermarkMode.hybrid);
    });
  });

  group('ProcessingStatus Tests', () {
    test('ProcessingStatus has all values', () {
      expect(ProcessingStatus.values.length, 5);
    });

    test('ProcessingStatus idle exists', () {
      expect(ProcessingStatus.values.contains(ProcessingStatus.idle), true);
    });
  });

  group('AppSettings Tests', () {
    test('AppSettings has default values', () {
      final settings = AppSettings();
      expect(settings.apiBaseUrl, AppConstants.defaultApiBaseUrl);
      expect(settings.defaultMode, WatermarkMode.hybrid);
      expect(settings.autoSelectBestMode, true);
      expect(settings.saveHistory, true);
      expect(settings.showNotifications, true);
      expect(settings.enableAnalytics, false);
    });

    test('AppSettings copyWith works correctly', () {
      final settings = AppSettings();
      final updated = settings.copyWith(
        apiBaseUrl: 'https://test.com',
        saveHistory: false,
      );

      expect(updated.apiBaseUrl, 'https://test.com');
      expect(updated.saveHistory, false);
      expect(updated.showNotifications, true); // unchanged
    });

    test('AppSettings copyWith with darkMode', () {
      final settings = AppSettings(darkModeEnabled: false);
      final updated = settings.copyWith(darkModeEnabled: true);

      expect(updated.darkModeEnabled, true);
    });
  });
}
