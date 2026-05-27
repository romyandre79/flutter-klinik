import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:kreatif_pos/core/api/api_config.dart';
import 'package:kreatif_pos/core/services/log_service.dart';

class ApiService {
  final Dio _dio;
  final LogService _logService = LogService();

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ));

  Future<void> setBaseUrl(String url) async {
    _dio.options.baseUrl = url;
  }

  Future<void> setAuthToken(String token) async {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<String?> login(String username, String password) async {
    // Log request (mask password)
    await _logService.logRequest('auth_login', {
      'username': username, 
      'password': '***'
    });

    try {
      // Use standard auth endpoint instead of executeFlow
      final response = await _dio.post('/api/auth/login', data: {
        'username': username,
        'password': password,
      });

      // Log success response
      await _logService.logResponse('auth_login', response.data);

      if (response.data['code'] == 200) {
        final token = response.data['data']['token'];
        return token;
      }
      return null;
    } catch (e) {
      // Log error
      await _logService.logResponse('auth_login', null, error: e);
      return null;
    }
  }

  Future<Response> executeFlow(String flowName, String menu, Map<String, dynamic> data) async {
    // Log the request
    await _logService.logRequest(flowName, data);

    final formData = FormData.fromMap({
      'flowname': flowName,
      'menu': menu,
      'search': 'true',
    });

    data.forEach((key, value) {
      if (value != null) {
        if (value is Map || value is List) {
          // Serialize objects and lists to JSON strings
          formData.fields.add(MapEntry(key, jsonEncode(value)));
        } else if (value is bool) {
          // Convert booleans to '1' or '0'
          formData.fields.add(MapEntry(key, value ? '1' : '0'));
        } else {
          // Convert everything else to string
          formData.fields.add(MapEntry(key, value.toString()));
        }
      }
    });

    try {
      final response = await _dio.post(ApiConfig.executeFlowEndpoint, data: formData);
      
      // Log the success response
      await _logService.logResponse(flowName, response.data);
      
      return response;
    } catch (e) {
      // Log the error
      await _logService.logResponse(flowName, null, error: e);
      rethrow;
    }
  }

  Future<Response> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(endpoint, queryParameters: queryParameters);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      final response = await _dio.post(endpoint, data: data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
