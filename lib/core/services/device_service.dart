import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DeviceService {
  static const String _salt = 'kreatif-klinik-2026';
  static String? _cachedDeviceId;

  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    String rawId = await _getRawMachineId();
    final bytes = utf8.encode(rawId + _salt);
    final hash = sha256.convert(bytes).toString().toUpperCase();
    final key = hash.substring(0, 16);
    _cachedDeviceId = '${key.substring(0, 4)}-${key.substring(4, 8)}-${key.substring(8, 12)}-${key.substring(12, 16)}';
    return _cachedDeviceId!;
  }

  static Future<String> _getRawMachineId() async {
    if (Platform.isWindows) {
      try {
        final result = await Process.run('reg', [
          'query',
          r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography',
          '/v', 'MachineGuid',
        ]);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final match = RegExp(r'MachineGuid\s+REG_SZ\s+(\S+)').firstMatch(output);
          if (match != null) return match.group(1)!.trim();
        }
      } catch (_) {}
    }
    return '${Platform.localHostname}-${Platform.operatingSystem}';
  }
}
