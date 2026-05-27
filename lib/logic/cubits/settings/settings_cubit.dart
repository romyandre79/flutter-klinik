import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/core/constants/app_constants.dart';
import 'package:kreatif_klinik/core/services/device_service.dart';
import 'package:kreatif_klinik/data/repositories/settings_repository.dart';
import 'package:kreatif_klinik/logic/cubits/settings/settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _repository;

  SettingsCubit({SettingsRepository? repository})
      : _repository = repository ?? SettingsRepository(),
        super(SettingsInitial());

  StoreInfo? _currentInfo;
  StoreInfo? get currentInfo => _currentInfo;

  Future<void> loadSettings() async {
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
      emit(SettingsError(message: 'Gagal memuat pengaturan: ${e.toString()}'));
    }
  }

  Future<void> updateStoreName(String name) async {
    if (name.trim().isEmpty) {
      emit(const SettingsError(message: 'Nama toko tidak boleh kosong'));
      return;
    }

    emit(SettingsUpdating());

    try {
      await _repository.setSetting(AppConstants.keyStoreName, name.trim());

      final updatedInfo = _currentInfo!.copyWith(name: name.trim());
      _currentInfo = updatedInfo;

      emit(SettingsUpdated(
        message: 'Nama toko berhasil diperbarui',
        storeInfo: updatedInfo,
      ));
    } catch (e) {
      emit(SettingsError(message: 'Gagal memperbarui nama: ${e.toString()}'));
    }
  }

  Future<void> updateStoreAddress(String address) async {
    if (address.trim().isEmpty) {
      emit(const SettingsError(message: 'Alamat tidak boleh kosong'));
      return;
    }

    emit(SettingsUpdating());

    try {
      await _repository.setSetting(
          AppConstants.keyStoreAddress, address.trim());

      final updatedInfo = _currentInfo!.copyWith(address: address.trim());
      _currentInfo = updatedInfo;

      emit(SettingsUpdated(
        message: 'Alamat berhasil diperbarui',
        storeInfo: updatedInfo,
      ));
    } catch (e) {
      emit(SettingsError(message: 'Gagal memperbarui alamat: ${e.toString()}'));
    }
  }

  Future<void> updateStorePhone(String phone) async {
    if (phone.trim().isEmpty) {
      emit(const SettingsError(message: 'Nomor HP tidak boleh kosong'));
      return;
    }

    emit(SettingsUpdating());

    try {
      await _repository.setSetting(AppConstants.keyStorePhone, phone.trim());

      final updatedInfo = _currentInfo!.copyWith(phone: phone.trim());
      _currentInfo = updatedInfo;

      emit(SettingsUpdated(
        message: 'Nomor HP berhasil diperbarui',
        storeInfo: updatedInfo,
      ));
    } catch (e) {
      emit(
          SettingsError(message: 'Gagal memperbarui nomor HP: ${e.toString()}'));
    }
  }

  Future<void> updateInvoicePrefix(String prefix) async {
    if (prefix.trim().isEmpty) {
      emit(const SettingsError(message: 'Prefix invoice tidak boleh kosong'));
      return;
    }

    if (prefix.trim().length > 10) {
      emit(const SettingsError(message: 'Prefix invoice maksimal 10 karakter'));
      return;
    }

    emit(SettingsUpdating());

    try {
      await _repository.setSetting(
          AppConstants.keyInvoicePrefix, prefix.trim().toUpperCase());

      final updatedInfo =
          _currentInfo!.copyWith(invoicePrefix: prefix.trim().toUpperCase());
      _currentInfo = updatedInfo;

      emit(SettingsUpdated(
        message: 'Prefix invoice berhasil diperbarui',
        storeInfo: updatedInfo,
      ));
    } catch (e) {
      emit(SettingsError(
          message: 'Gagal memperbarui prefix invoice: ${e.toString()}'));
    }
  }

  Future<void> updateFonnteToken(String token) async {
    emit(SettingsUpdating());

    try {
      await _repository.setSetting('fonnte_token', token.trim());

      final updatedInfo = _currentInfo!.copyWith(fonnteToken: token.trim());
      _currentInfo = updatedInfo;

      emit(SettingsUpdated(
        message: 'Token Fonnte berhasil diperbarui',
        storeInfo: updatedInfo,
      ));
    } catch (e) {
      emit(SettingsError(
          message: 'Gagal memperbarui token Fonnte: ${e.toString()}'));
    }
  }

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
          message: 'Gagal memperbarui ID Cabang: ${e.toString()}'));
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
          message: 'Gagal memperbarui Kode Cabang: ${e.toString()}'));
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
          message: 'Gagal memperbarui Nama Customer: ${e.toString()}'));
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
          message: 'Gagal memperbarui No WA Customer: ${e.toString()}'));
    }
  }
}
