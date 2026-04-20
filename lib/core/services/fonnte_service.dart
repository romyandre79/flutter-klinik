import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kreatif_klinik/data/repositories/settings_repository.dart';


class FonnteService {
  static final FonnteService _instance = FonnteService._internal();
  factory FonnteService() => _instance;
  FonnteService._internal();

  final SettingsRepository _settingsRepository = SettingsRepository();

  Future<bool> sendMessage({
    required String target,
    required String message,
  }) async {
    final token = await _settingsRepository.getSetting('fonnte_token');
    
    if (token == null || token.isEmpty) {
      throw Exception('Token Fonnte belum dikonfigurasi di Pengaturan');
    }

    final url = Uri.parse('https://api.fonnte.com/send');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': token,
        },
        body: {
          'target': target,
          'message': message,
        },
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        return true;
      } else {
        throw Exception(data['reason'] ?? 'Gagal mengirim pesan via Fonnte');
      }
    } catch (e) {
      throw Exception('Koneksi Fonnte error: ${e.toString()}');
    }
  }
}
