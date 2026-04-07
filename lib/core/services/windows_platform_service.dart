// lib/core/services/windows_platform_service.dart

import 'dart:io';
import 'dart:convert';

class WindowsPlatformService {
  /// Fetches Battery, RAM, and Location from Windows.
  static Future<Map<String, dynamic>> getSystemStats() async {
    try {
      // 1. Get Battery Level & Status (Original Logic)
      final battResult = await Process.run('powershell', [
        '-Command',
        'Get-CimInstance -ClassName Win32_Battery | Select-Object EstimatedChargeRemaining, BatteryStatus | ConvertTo-Json',
      ]);

      // 2. Get Free RAM (Original Logic)
      final ramResult = await Process.run('powershell', [
        '-Command',
        '(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory',
      ]);

      // 3. 🌍 NEW: Get Location via IP (Windows Desktop standard)
      Map<String, double> location = {'lat': 0.0, 'lon': 0.0};
      try {
        final client = HttpClient();
        // Using ip-api (free, no-key needed for low volume testing)
        final request = await client.getUrl(
          Uri.parse('http://ip-api.com/json/'),
        );
        final response = await request.close();
        final content = await response.transform(utf8.decoder).join();
        final locData = jsonDecode(content);

        if (locData['status'] == 'success') {
          location = {
            'lat': (locData['lat'] as num).toDouble(),
            'lon': (locData['lon'] as num).toDouble(),
          };
        }
      } catch (e) {
        print('[WindowsPlatform] 📍 Location Fetch Failed: $e');
      }

      Map<String, dynamic> stats = {
        'battery': {'level': 100, 'isCharging': true},
        'ram': 'Unknown',
        'os': 'Windows Desktop',
        'location': location, // 🚀 Added to stats map
      };

      if (battResult.stdout.toString().isNotEmpty) {
        try {
          final data = jsonDecode(battResult.stdout.toString());
          stats['battery'] = {
            'level': data['EstimatedChargeRemaining'] ?? 100,
            'isCharging': data['BatteryStatus'] == 2,
          };
        } catch (_) {}
      }

      if (ramResult.stdout.toString().isNotEmpty) {
        final kb = int.tryParse(ramResult.stdout.toString().trim()) ?? 0;
        stats['ram'] = "${(kb / 1024).toStringAsFixed(0)} MB";
      }

      return stats;
    } catch (e) {
      print('[WindowsPlatform] ❌ Error: $e');
      return {'os': 'Windows', 'error': 'Stats unavailable'};
    }
  }

  // Windows App Launchers using URI Schemes (Original Logic)
  static Future<void> openYouTube() async => _launch('https://www.youtube.com');
  static Future<void> openSpotify() async => _launch('spotify:');
  static Future<void> openCalendar() async => _launch('outlookcal:');
  static Future<void> openAlarms() async => _launch('ms-clock:');

  static Future<void> _launch(String uri) async {
    await Process.run('start', [uri], runInShell: true);
  }
}
