import 'dart:io';

void main() {
  final targetDirs = ['kreatif-otopart', 'kreatif-pos', 'kreatif-wargamu'];
  
  for (final dirName in targetDirs) {
    final repoDir = Directory('../$dirName');
    if (!repoDir.existsSync()) {
      print('Warning: Directory ${repoDir.path} does not exist. Skipping.');
      continue;
    }
    
    print('Processing repo: $dirName...');
    final packageName = dirName.replaceAll('-', '_');
    
    try {
      // 1. Copy DeviceService
      _copyDeviceService(dirName, packageName);
      
      // 2. Copy build configuration files
      _copyBuildFiles(dirName);
      
      // 3. Update app_constants.dart
      _updateAppConstants(dirName);
      
      // 4. Update database_helper.dart
      _updateDatabaseHelper(dirName);
      
      // 5. Update settings_state.dart
      _updateSettingsState(dirName);
      
      // 6. Update settings_cubit.dart
      _updateSettingsCubit(dirName, packageName);
      
      // 7. Update sync_service.dart
      _updateSyncService(dirName);
      
      // 8. Update settings_screen.dart
      _updateSettingsScreen(dirName, packageName);
      
      print('Successfully finished processing $dirName.\n');
    } catch (e) {
      print('Error processing $dirName: $e');
    }
  }
}

void _copyDeviceService(String dirName, String packageName) {
  final source = File('lib/core/services/device_service.dart');
  final dest = File('../$dirName/lib/core/services/device_service.dart');
  dest.parent.createSync(recursive: true);
  
  var content = source.readAsStringSync();
  // Customize the salt per repo
  content = content.replaceAll('kreatif-klinik-2026', 'kreatif-$dirName-2026');
  dest.writeAsStringSync(content);
}

void _copyBuildFiles(String dirName) {
  // configure_build.dart
  final sourceConfig = File('scripts/configure_build.dart');
  final destConfig = File('../$dirName/scripts/configure_build.dart');
  destConfig.parent.createSync(recursive: true);
  
  var configContent = sourceConfig.readAsStringSync();
  destConfig.writeAsStringSync(configContent);

  // build.bat
  final sourceBat = File('build.bat');
  final destBat = File('../$dirName/build.bat');
  destBat.writeAsStringSync(sourceBat.readAsStringSync());

  // build.sh
  final sourceSh = File('build.sh');
  final destSh = File('../$dirName/build.sh');
  destSh.writeAsStringSync(sourceSh.readAsStringSync());
}

void _updateAppConstants(String dirName) {
  final file = File('../$dirName/lib/core/constants/app_constants.dart');
  if (!file.existsSync()) return;
  var content = file.readAsStringSync();

  if (!content.contains('keyBranchId')) {
    content = content.replaceAll(
      "static const String keyLastInvoiceNumber = 'last_invoice_number';",
      "static const String keyLastInvoiceNumber = 'last_invoice_number';\n  static const String keyBranchId = 'branch_id';\n  static const String keyBranchCode = 'branch_code';\n  static const String keyCustomerName = 'customer_name';\n  static const String keyCustomerWa = 'customer_wa';"
    );
  }

  if (!content.contains('defaultBranchId')) {
    content = content.replaceAll(
      "static const String defaultStorePhone = '-';",
      "static const String defaultStorePhone = '-';\n  static const String defaultBranchId = '';\n  static const String defaultBranchCode = '';\n  static const String defaultCustomerName = '';\n  static const String defaultCustomerWa = '';"
    );
  }

  // Replace isDemoMode with bool.fromEnvironment
  content = content.replaceAll(
    RegExp(r'static const bool isDemoMode = .*?;'),
    "static const bool isDemoMode = bool.fromEnvironment('DEMO', defaultValue: true);"
  );

  file.writeAsStringSync(content);
}

void _updateDatabaseHelper(String dirName) {
  final file = File('../$dirName/lib/data/database/database_helper.dart');
  if (!file.existsSync()) return;
  var content = file.readAsStringSync();

  if (!content.contains('AppConstants.keyBranchId')) {
    content = content.replaceAll(
      "      AppConstants.keyLastInvoiceNumber: '0',\n      'fonnte_token': '',\n    };",
      "      AppConstants.keyLastInvoiceNumber: '0',\n      'fonnte_token': '',\n      AppConstants.keyBranchId: AppConstants.defaultBranchId,\n      AppConstants.keyBranchCode: AppConstants.defaultBranchCode,\n      AppConstants.keyCustomerName: AppConstants.defaultCustomerName,\n      AppConstants.keyCustomerWa: AppConstants.defaultCustomerWa,\n    };"
    );
  }

  file.writeAsStringSync(content);
}

void _updateSettingsState(String dirName) {
  final source = File('lib/logic/cubits/settings/settings_state.dart');
  final dest = File('../$dirName/lib/logic/cubits/settings/settings_state.dart');
  if (!dest.existsSync()) return;
  
  dest.writeAsStringSync(source.readAsStringSync());
}

void _updateSettingsCubit(String dirName, String packageName) {
  final file = File('../$dirName/lib/logic/cubits/settings/settings_cubit.dart');
  if (!file.existsSync()) return;
  var content = file.readAsStringSync();

  // Add DeviceService import if missing
  if (!content.contains('device_service.dart')) {
    content = content.replaceAll(
      "import 'package:kreatif_${packageName}/logic/cubits/settings/settings_state.dart';",
      "import 'package:kreatif_${packageName}/logic/cubits/settings/settings_state.dart';\nimport 'package:kreatif_${packageName}/core/services/device_service.dart';"
    );
  }

  // Replace loadSettings() method
  final loadSettingsStart = content.indexOf('Future<void> loadSettings() async {');
  if (loadSettingsStart != -1) {
    final loadSettingsEndToken = 'emit(SettingsLoaded(storeInfo: storeInfo));\n    } catch (e) {\n      emit(SettingsError(message: \'Gagal memuat pengaturan: \${e.toString()}\'));\n    }\n  }';
    final loadSettingsEndIndex = content.indexOf(loadSettingsEndToken);
    
    if (loadSettingsEndIndex != -1) {
      final oldMethod = content.substring(loadSettingsStart, loadSettingsEndIndex + loadSettingsEndToken.length);
      final newMethod = '''Future<void> loadSettings() async {
    emit(SettingsLoading());
    try {
      final results = await Future.wait([
        _repository.getAllSettings(),
        DeviceService.getDeviceId(),
      ]);

      var settings = results[0] as Map<String, String>;
      final deviceId = results[1] as String;

      // In production (non-demo mode), we enforce and update the static constants in the database
      if (!AppConstants.isDemoMode) {
        bool needsUpdate = false;
        if (settings[AppConstants.keyStoreName] != AppConstants.defaultStoreName) {
          await _repository.setSetting(AppConstants.keyStoreName, AppConstants.defaultStoreName);
          needsUpdate = true;
        }
        if (settings[AppConstants.keyStoreAddress] != AppConstants.defaultStoreAddress) {
          await _repository.setSetting(AppConstants.keyStoreAddress, AppConstants.defaultStoreAddress);
          needsUpdate = true;
        }
        if (settings[AppConstants.keyStorePhone] != AppConstants.defaultStorePhone) {
          await _repository.setSetting(AppConstants.keyStorePhone, AppConstants.defaultStorePhone);
          needsUpdate = true;
        }
        if (settings[AppConstants.keyBranchId] != AppConstants.defaultBranchId) {
          await _repository.setSetting(AppConstants.keyBranchId, AppConstants.defaultBranchId);
          needsUpdate = true;
        }
        if (settings[AppConstants.keyBranchCode] != AppConstants.defaultBranchCode) {
          await _repository.setSetting(AppConstants.keyBranchCode, AppConstants.defaultBranchCode);
          needsUpdate = true;
        }
        if (settings[AppConstants.keyCustomerName] != AppConstants.defaultCustomerName) {
          await _repository.setSetting(AppConstants.keyCustomerName, AppConstants.defaultCustomerName);
          needsUpdate = true;
        }
        if (settings[AppConstants.keyCustomerWa] != AppConstants.defaultCustomerWa) {
          await _repository.setSetting(AppConstants.keyCustomerWa, AppConstants.defaultCustomerWa);
          needsUpdate = true;
        }
        if (needsUpdate) {
          settings = await _repository.getAllSettings();
        }
      }

      final storeInfo = StoreInfo(
        name: settings[AppConstants.keyStoreName] ??
            AppConstants.defaultStoreName,
        address: settings[AppConstants.keyStoreAddress] ??
            AppConstants.defaultStoreAddress,
        phone: settings[AppConstants.keyStorePhone] ??
            AppConstants.defaultStorePhone,
        invoicePrefix: settings[AppConstants.keyInvoicePrefix] ??
            AppConstants.defaultInvoicePrefix,
        fonnteToken: settings['fonnte_token'] ?? '',
        deviceId: deviceId,
        branchId: settings[AppConstants.keyBranchId] ?? AppConstants.defaultBranchId,
        branchCode: settings[AppConstants.keyBranchCode] ?? AppConstants.defaultBranchCode,
        customerName: settings[AppConstants.keyCustomerName] ?? AppConstants.defaultCustomerName,
        customerWa: settings[AppConstants.keyCustomerWa] ?? AppConstants.defaultCustomerWa,
      );

      _currentInfo = storeInfo;
      emit(SettingsLoaded(storeInfo: storeInfo));
    } catch (e) {
      emit(SettingsError(message: 'Gagal memuat pengaturan: \${e.toString()}'));
    }
  }''';
      
      content = content.replaceRange(loadSettingsStart, loadSettingsStart + oldMethod.length, newMethod);
    }
  }

  // Add update methods before the final closing brace
  if (!content.contains('updateCustomerName')) {
    final lastBrace = content.lastIndexOf('}');
    if (lastBrace != -1) {
      final updateMethods = '''

  Future<void> updateBranchId(String branchId) async {
    emit(SettingsUpdating());

    try {
      await _repository.setSetting(AppConstants.keyBranchId, branchId.trim());

      final updatedInfo = _currentInfo!.copyWith(branchId: branchId.trim());
      _currentInfo = updatedInfo;

      emit(SettingsUpdated(
        message: 'ID Cabang berhasil diperbarui',
        storeInfo: updatedInfo,
      ));
    } catch (e) {
      emit(SettingsError(
          message: 'Gagal memperbarui ID Cabang: \${e.toString()}'));
    }
  }

  Future<void> updateBranchCode(String branchCode) async {
    emit(SettingsUpdating());

    try {
      await _repository.setSetting(AppConstants.keyBranchCode, branchCode.trim());

      final updatedInfo = _currentInfo!.copyWith(branchCode: branchCode.trim());
      _currentInfo = updatedInfo;

      emit(SettingsUpdated(
        message: 'Kode Cabang berhasil diperbarui',
        storeInfo: updatedInfo,
      ));
    } catch (e) {
      emit(SettingsError(
          message: 'Gagal memperbarui Kode Cabang: \${e.toString()}'));
    }
  }

  Future<void> updateCustomerName(String customerName) async {
    emit(SettingsUpdating());

    try {
      await _repository.setSetting(AppConstants.keyCustomerName, customerName.trim());

      final updatedInfo = _currentInfo!.copyWith(customerName: customerName.trim());
      _currentInfo = updatedInfo;

      emit(SettingsUpdated(
        message: 'Nama Customer berhasil diperbarui',
        storeInfo: updatedInfo,
      ));
    } catch (e) {
      emit(SettingsError(
          message: 'Gagal memperbarui Nama Customer: \${e.toString()}'));
    }
  }

  Future<void> updateCustomerWa(String customerWa) async {
    emit(SettingsUpdating());

    try {
      await _repository.setSetting(AppConstants.keyCustomerWa, customerWa.trim());

      final updatedInfo = _currentInfo!.copyWith(customerWa: customerWa.trim());
      _currentInfo = updatedInfo;

      emit(SettingsUpdated(
        message: 'No WA Customer berhasil diperbarui',
        storeInfo: updatedInfo,
      ));
    } catch (e) {
      emit(SettingsError(
          message: 'Gagal memperbarui No WA Customer: \${e.toString()}'));
    }
  }
''';
      content = content.substring(0, lastBrace) + updateMethods + '}';
    }
  }

  file.writeAsStringSync(content);
}

void _updateSyncService(String dirName) {
  final file = File('../$dirName/lib/core/services/sync_service.dart');
  if (!file.existsSync()) return;
  var content = file.readAsStringSync();

  if (!content.contains("payload['branch_id']")) {
    content = content.replaceAll(
      "    final List<Map<String, dynamic>> maps = await db.query(\n      'orders',",
      "    // Fetch branch info from settings\n    final settingsResult = await db.query('app_settings');\n    final settings = Map.fromEntries(\n      settingsResult.map((e) => MapEntry(e['key'] as String, e['value'] as String)),\n    );\n    final branchId = settings[AppConstants.keyBranchId] ?? '';\n    final branchCode = settings[AppConstants.keyBranchCode] ?? '';\n\n    final List<Map<String, dynamic>> maps = await db.query(\n      'orders',"
    );

    content = content.replaceAll(
      "        final payload = order.toMap();\n        payload['items'] = items.map((e) => e.toMap()).toList();",
      "        final payload = order.toMap();\n        payload['items'] = items.map((e) => e.toMap()).toList();\n        payload['branch_id'] = branchId;\n        payload['branch_code'] = branchCode;"
    );
  }

  file.writeAsStringSync(content);
}

void _updateSettingsScreen(String dirName, String packageName) {
  final file = File('../$dirName/lib/presentation/screens/settings/settings_screen.dart');
  if (!file.existsSync()) return;
  var content = file.readAsStringSync();

  // 1. Add Clipboard and Services imports
  if (!content.contains("import 'package:flutter/services.dart';")) {
    content = "import 'package:flutter/services.dart';\n" + content;
  }

  // 2. Modify _buildSettingTile signature and body robustly
  if (!content.contains("bool locked = false,")) {
    content = content.replaceAll(
      "Widget _buildSettingTile({",
      "Widget _buildSettingTile({\n    bool locked = false,"
    );

    content = content.replaceAll(
      "// Icon container\n              Container(\n                width: 40,\n                height: 40,\n                decoration: BoxDecoration(\n                  color: AppThemeColors.primarySurface,",
      "// Icon container\n              Container(\n                width: 40,\n                height: 40,\n                decoration: BoxDecoration(\n                  color: locked\n                      ? AppThemeColors.textSecondary.withValues(alpha: 0.08)\n                      : AppThemeColors.primarySurface,"
    );

    content = content.replaceAll(
      "child: Icon(icon, color: AppThemeColors.primary, size: 20),",
      "child: Icon(\n                  icon,\n                  color: locked ? AppThemeColors.textSecondary : AppThemeColors.primary,\n                  size: 20,\n                ),"
    );

    content = content.replaceAll(
      "title,\n                      style: AppTypography.titleSmall.copyWith(\n                        fontWeight: FontWeight.w500,\n                      ),",
      "title,\n                      style: AppTypography.titleSmall.copyWith(\n                        fontWeight: FontWeight.w500,\n                        color: locked ? AppThemeColors.textSecondary : null,\n                      ),"
    );

    content = content.replaceAll(
      "// Arrow or edit icon\n              if (showArrow && onTap != null && trailing == null)",
      "// Lock icon when locked\n              if (locked)\n                const Icon(\n                  Icons.lock_outline,\n                  color: AppThemeColors.textSecondary,\n                  size: 14,\n                ),\n              // Arrow or edit icon\n              if (!locked && showArrow && onTap != null && trailing == null)"
    );
  }

  // 3. Insert _buildDeviceKeyTile helper before final closing brace
  if (!content.contains('_buildDeviceKeyTile')) {
    final lastBrace = content.lastIndexOf('}');
    if (lastBrace != -1) {
      final helperMethod = '''

  Widget _buildDeviceKeyTile(String deviceId) {
    final displayKey = deviceId.isEmpty ? 'Memuat...' : deviceId;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
              borderRadius: AppRadius.smRadius,
            ),
            child: const Icon(Icons.fingerprint, color: Color(0xFF6A1B9A), size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Device Key', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w500)),
                Text(displayKey, style: AppTypography.bodySmall.copyWith(
                  color: const Color(0xFF6A1B9A), fontWeight: FontWeight.w600, letterSpacing: 1.5,
                )),
              ],
            ),
          ),
          if (deviceId.isNotEmpty)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: deviceId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Device Key disalin'), backgroundColor: Color(0xFF6A1B9A), duration: Duration(seconds: 2)),
                );
              },
              borderRadius: AppRadius.smRadius,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                  borderRadius: AppRadius.smRadius,
                ),
                child: const Icon(Icons.copy_outlined, color: Color(0xFF6A1B9A), size: 14),
              ),
            ),
        ],
      ),
    );
  }
''';
      content = content.substring(0, lastBrace) + helperMethod + '}';
    }
  }

  // 4. Update store info section children
  if (!content.contains('customerName')) {
    final storeSectionStart = content.indexOf('_buildSection(');
    if (storeSectionStart != -1) {
      final childrenStartToken = 'children: [';
      final childrenStartIndex = content.indexOf(childrenStartToken, storeSectionStart);
      if (childrenStartIndex != -1) {
        final phoneIndex = content.indexOf('Icons.phone', childrenStartIndex);
        if (phoneIndex != -1) {
          final sectionEndIndex = content.indexOf('],', phoneIndex);
          if (sectionEndIndex != -1) {
            final newChildren = '''
                              _buildSettingTile(
                                context: context,
                                icon: Icons.store,
                                title: 'Nama Toko / Klinik',
                                subtitle: storeInfo?.name ?? AppConstants.defaultStoreName,
                                locked: !AppConstants.isDemoMode,
                                onTap: AppConstants.isDemoMode ? () => _showEditDialog(
                                  title: 'Ubah Data Nama Toko / Klinik',
                                  currentValue: storeInfo?.name ?? AppConstants.defaultStoreName,
                                  hint: 'Masukkan nama',
                                  icon: Icons.store,
                                  onSave: (value) => _settingsCubit.updateStoreName(value),
                                ) : null,
                              ),
                              _buildDivider(),
                              _buildSettingTile(
                                context: context,
                                icon: Icons.location_on,
                                title: 'Alamat',
                                subtitle: storeInfo?.address ?? AppConstants.defaultStoreAddress,
                                locked: !AppConstants.isDemoMode,
                                onTap: AppConstants.isDemoMode ? () => _showEditDialog(
                                  title: 'Ubah Data Alamat',
                                  currentValue: storeInfo?.address ?? AppConstants.defaultStoreAddress,
                                  hint: 'Masukkan alamat',
                                  icon: Icons.location_on,
                                  maxLines: 2,
                                  onSave: (value) => _settingsCubit.updateStoreAddress(value),
                                ) : null,
                              ),
                              _buildDivider(),
                              _buildSettingTile(
                                context: context,
                                icon: Icons.phone,
                                title: 'Nomor HP',
                                subtitle: storeInfo?.phone ?? AppConstants.defaultStorePhone,
                                locked: !AppConstants.isDemoMode,
                                onTap: AppConstants.isDemoMode ? () => _showEditDialog(
                                  title: 'Ubah Data Nomor HP',
                                  currentValue: storeInfo?.phone ?? AppConstants.defaultStorePhone,
                                  hint: 'Masukkan nomor HP',
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                  onSave: (value) => _settingsCubit.updateStorePhone(value),
                                ) : null,
                              ),
                              _buildDivider(),
                              _buildSettingTile(
                                context: context,
                                icon: Icons.badge_outlined,
                                title: 'ID Cabang',
                                subtitle: (storeInfo?.branchId == null || storeInfo!.branchId.isEmpty)
                                    ? 'Belum diatur'
                                    : storeInfo.branchId,
                                locked: !AppConstants.isDemoMode,
                                onTap: AppConstants.isDemoMode ? () => _showEditDialog(
                                  title: 'Ubah Data ID Cabang',
                                  currentValue: storeInfo?.branchId ?? '',
                                  hint: 'Masukkan ID Cabang',
                                  icon: Icons.badge_outlined,
                                  onSave: (value) => _settingsCubit.updateBranchId(value),
                                ) : null,
                              ),
                              _buildDivider(),
                              _buildSettingTile(
                                context: context,
                                icon: Icons.code,
                                title: 'Kode Cabang',
                                subtitle: (storeInfo?.branchCode == null || storeInfo!.branchCode.isEmpty)
                                    ? 'Belum diatur'
                                    : storeInfo.branchCode,
                                locked: !AppConstants.isDemoMode,
                                onTap: AppConstants.isDemoMode ? () => _showEditDialog(
                                  title: 'Ubah Data Kode Cabang',
                                  currentValue: storeInfo?.branchCode ?? '',
                                  hint: 'Masukkan Kode Cabang',
                                  icon: Icons.code,
                                  onSave: (value) => _settingsCubit.updateBranchCode(value),
                                ) : null,
                              ),
                              _buildDivider(),
                              _buildSettingTile(
                                context: context,
                                icon: Icons.person_pin,
                                title: 'Nama Customer',
                                subtitle: (storeInfo?.customerName == null || storeInfo!.customerName.isEmpty)
                                    ? 'Belum diatur'
                                    : storeInfo.customerName,
                                locked: !AppConstants.isDemoMode,
                                onTap: AppConstants.isDemoMode ? () => _showEditDialog(
                                  title: 'Ubah Nama Customer',
                                  currentValue: storeInfo?.customerName ?? '',
                                  hint: 'Masukkan Nama Customer',
                                  icon: Icons.person_pin,
                                  onSave: (value) => _settingsCubit.updateCustomerName(value),
                                ) : null,
                              ),
                              _buildDivider(),
                              _buildSettingTile(
                                context: context,
                                icon: Icons.chat_bubble_outline,
                                title: 'No WA Customer',
                                subtitle: (storeInfo?.customerWa == null || storeInfo!.customerWa.isEmpty)
                                    ? 'Belum diatur'
                                    : storeInfo.customerWa,
                                locked: !AppConstants.isDemoMode,
                                onTap: AppConstants.isDemoMode ? () => _showEditDialog(
                                  title: 'Ubah No WA Customer',
                                  currentValue: storeInfo?.customerWa ?? '',
                                  hint: 'Masukkan No WA Customer',
                                  icon: Icons.chat_bubble_outline,
                                  keyboardType: TextInputType.phone,
                                  onSave: (value) => _settingsCubit.updateCustomerWa(value),
                                ) : null,
                              ),
                              _buildDivider(),
                              _buildDeviceKeyTile(storeInfo?.deviceId ?? ''),
''';
            content = content.replaceRange(childrenStartIndex + childrenStartToken.length, sectionEndIndex, newChildren);
          }
        }
      }
    }
  }

  file.writeAsStringSync(content);
}
