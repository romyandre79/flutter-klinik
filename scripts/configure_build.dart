// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isNotEmpty && args[0] == '--copy') {
    if (args.length < 2) {
      print('Usage: dart scripts/configure_build.dart --copy <platform>');
      exit(1);
    }
    final platform = args[1].toLowerCase();
    _handleCopy(platform);
    return;
  }

  print('==========================================');
  print('  KREATIF KLINIK BUILD CONFIGURATOR');
  print('==========================================');
  
  stdout.write('Apakah ini build DEMO? (y/n): ');
  final isDemoInput = stdin.readLineSync()?.trim().toLowerCase() ?? 'y';
  final isDemo = isDemoInput == 'y';

  String storeName = 'Toko Serba Ada';
  String storeAddress = 'Indonesia';
  String storePhone = '-';
  String branchId = '';
  String branchCode = '';
  String customerName = '';
  String customerWa = '';

  if (!isDemo) {
    print('\n--- Konfigurasi Informasi Apotek/Klinik (Produksi) ---');
    
    stdout.write('Masukkan Nama Apotek/Klinik: ');
    storeName = stdin.readLineSync()?.trim() ?? 'Toko Serba Ada';
    if (storeName.isEmpty) storeName = 'Toko Serba Ada';

    stdout.write('Masukkan Alamat: ');
    storeAddress = stdin.readLineSync()?.trim() ?? 'Indonesia';
    if (storeAddress.isEmpty) storeAddress = 'Indonesia';

    stdout.write('Masukkan Nomor HP: ');
    storePhone = stdin.readLineSync()?.trim() ?? '-';
    if (storePhone.isEmpty) storePhone = '-';

    stdout.write('Masukkan ID Cabang: ');
    branchId = stdin.readLineSync()?.trim() ?? '';

    stdout.write('Masukkan Kode Cabang: ');
    branchCode = stdin.readLineSync()?.trim() ?? '';

    stdout.write('Masukkan Nama Customer: ');
    customerName = stdin.readLineSync()?.trim() ?? '';

    stdout.write('Masukkan No WA Customer: ');
    customerWa = stdin.readLineSync()?.trim() ?? '';
  }

  stdout.write('\nMasukkan folder tujuan hasil build (kosongkan jika tidak ingin disalin): ');
  final destFolder = stdin.readLineSync()?.trim() ?? '';

  // Save destination folder to .build_temp.json
  final tempFile = File('.build_temp.json');
  tempFile.writeAsStringSync(jsonEncode({'dest': destFolder}));

  // Update lib/core/constants/app_constants.dart
  final file = File('lib/core/constants/app_constants.dart');
  if (!file.existsSync()) {
    print('Error: lib/core/constants/app_constants.dart tidak ditemukan!');
    exit(1);
  }

  var content = file.readAsStringSync();

  // Replace default static variables
  content = _replaceConstString(content, 'defaultStoreName', storeName);
  content = _replaceConstString(content, 'defaultStoreAddress', storeAddress);
  content = _replaceConstString(content, 'defaultStorePhone', storePhone);
  content = _replaceConstString(content, 'defaultBranchId', branchId);
  content = _replaceConstString(content, 'defaultBranchCode', branchCode);
  content = _replaceConstString(content, 'defaultCustomerName', customerName);
  content = _replaceConstString(content, 'defaultCustomerWa', customerWa);
  content = _replaceConstBool(content, 'isDemoMode', isDemo);

  file.writeAsStringSync(content);

  print('\nKonfigurasi berhasil disimpan ke lib/core/constants/app_constants.dart:');
  print('  isDemoMode = $isDemo');
  print('  defaultStoreName = "$storeName"');
  print('  defaultStoreAddress = "$storeAddress"');
  print('  defaultStorePhone = "$storePhone"');
  print('  defaultBranchId = "$branchId"');
  print('  defaultBranchCode = "$branchCode"');
  print('  defaultCustomerName = "$customerName"');
  print('  defaultCustomerWa = "$customerWa"');
  if (destFolder.isNotEmpty) {
    print('  Folder Hasil Build = "$destFolder"');
  } else {
    print('  Folder Hasil Build = (Tidak disalin)');
  }
  print('==========================================\n');
}

void _handleCopy(String platform) {
  final tempFile = File('.build_temp.json');
  if (!tempFile.existsSync()) {
    return;
  }

  try {
    final data = jsonDecode(tempFile.readAsStringSync()) as Map<String, dynamic>;
    final destPath = data['dest'] as String? ?? '';
    if (destPath.trim().isEmpty) {
      print('Informasi: Folder tujuan hasil build tidak diatur. File tidak disalin.');
      return;
    }

    final destDir = Directory(destPath.trim());
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }

    print('\n==========================================');
    print('  MENYALIN HASIL BUILD');
    print('==========================================');
    print('Folder Tujuan: ${destDir.absolute.path}');

    final separator = Platform.pathSeparator;

    if (platform == 'windows' || platform == 'all') {
      final sourceDir = Directory('build/windows/x64/runner/Release');
      if (sourceDir.existsSync()) {
        print('Menyalin Windows Release Build...');
        final windowsDest = Directory('${destDir.path}${separator}windows');
        if (windowsDest.existsSync()) {
          windowsDest.deleteSync(recursive: true);
        }
        _copyDirectory(sourceDir, windowsDest);
        print('Windows Release Build berhasil disalin ke: ${windowsDest.path}');
      } else {
        if (platform == 'windows') {
          print('Warning: Build Windows tidak ditemukan di ${sourceDir.path}');
        }
      }
    }

    if (platform == 'apk' || platform == 'all') {
      final sourceFile = File('build/app/outputs/flutter-apk/app-release.apk');
      if (sourceFile.existsSync()) {
        print('Menyalin Android APK...');
        final destFile = File('${destDir.path}${separator}app-release.apk');
        sourceFile.copySync(destFile.path);
        print('Android APK berhasil disalin ke: ${destFile.path}');
      } else {
        if (platform == 'apk') {
          print('Warning: Build APK tidak ditemukan di ${sourceFile.path}');
        }
      }
    }

    print('==========================================\n');
  } catch (e) {
    print('Gagal menyalin hasil build: $e');
  }
}

void _copyDirectory(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  final separator = Platform.pathSeparator;
  for (final entity in source.listSync(recursive: false)) {
    final name = entity.path.split(separator).last;
    if (entity is Directory) {
      _copyDirectory(entity, Directory('${destination.path}$separator$name'));
    } else if (entity is File) {
      entity.copySync('${destination.path}$separator$name');
    }
  }
}

String _replaceConstString(String content, String name, String value) {
  final regExp = RegExp("static const String $name = ['.\"].*?['\"];");
  if (content.contains(regExp)) {
    return content.replaceAll(regExp, "static const String $name = '$value';");
  } else {
    // If not found, insert it before isDemoMode
    final insertIndex = content.indexOf("static const bool isDemoMode");
    if (insertIndex != -1) {
      final insertText = "static const String $name = '$value';\n  ";
      return content.substring(0, insertIndex) + insertText + content.substring(insertIndex);
    }
  }
  return content;
}

String _replaceConstBool(String content, String name, bool value) {
  final regExpPattern = 'static const bool $name = .*?;';
  final regExp = RegExp(regExpPattern);
  return content.replaceAll(regExp, 'static const bool $name = $value;');
}
