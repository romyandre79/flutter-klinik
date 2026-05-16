import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/core/constants/app_constants.dart';
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
      final settings = await _repository.getAllSettings();

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
}
