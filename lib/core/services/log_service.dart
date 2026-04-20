import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LogService {
  static final LogService _instance = LogService._internal();

  factory LogService() {
    return _instance;
  }

  LogService._internal();

  Future<File> get _logFile async {
    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory('${directory.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return File('${logDir.path}/api_logs_$date.txt');
  }

  Future<void> logRequest(String flowName, Map<String, dynamic> data) async {
    try {
      final file = await _logFile;
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final logMessage = '[$timestamp] [REQUEST] [FLOW: $flowName]\nDATA: $data\n${'-' * 50}\n';
      
      await file.writeAsString(logMessage, mode: FileMode.append);
      if (kDebugMode) {
        print('📝 Logged Request: $flowName');
      }
    } catch (e) {
      debugPrint('Error logging request: $e');
    }
  }

  Future<void> logResponse(String flowName, dynamic response, {Object? error}) async {
    try {
      final file = await _logFile;
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      
      String logMessage;
      if (error != null) {
        logMessage = '[$timestamp] [ERROR] [FLOW: $flowName]\nERROR: $error\n${'-' * 50}\n';
      } else {
        logMessage = '[$timestamp] [RESPONSE] [FLOW: $flowName]\nDATA: $response\n${'-' * 50}\n';
      }

      await file.writeAsString(logMessage, mode: FileMode.append);
       if (kDebugMode) {
        print('📝 Logged Response: $flowName');
      }
    } catch (e) {
      debugPrint('Error logging response: $e');
    }
  }

  Future<void> log(String category, String message) async {
    try {
      final file = await _logFile;
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final logMessage = '[$timestamp] [$category] $message\n${'-' * 50}\n';
      await file.writeAsString(logMessage, mode: FileMode.append);
    } catch (e) {
      debugPrint('Error logging: $e');
    }
  }

  Future<String> getLogPath() async {
    final file = await _logFile;
    return file.path;
  }
}
