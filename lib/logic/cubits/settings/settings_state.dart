import 'package:equatable/equatable.dart';

class StoreInfo {
  final String name;
  final String address;
  final String phone;
  final String invoicePrefix;
  final String fonnteToken;
  final String deviceId;
  final String branchId;
  final String branchCode;
  final String customerName;
  final String customerWa;

  const StoreInfo({
    required this.name,
    required this.address,
    required this.phone,
    required this.invoicePrefix,
    required this.fonnteToken,
    this.deviceId = '',
    this.branchId = '',
    this.branchCode = '',
    this.customerName = '',
    this.customerWa = '',
  });

  StoreInfo copyWith({
    String? name,
    String? address,
    String? phone,
    String? invoicePrefix,
    String? fonnteToken,
    String? deviceId,
    String? branchId,
    String? branchCode,
    String? customerName,
    String? customerWa,
  }) {
    return StoreInfo(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      fonnteToken: fonnteToken ?? this.fonnteToken,
      deviceId: deviceId ?? this.deviceId,
      branchId: branchId ?? this.branchId,
      branchCode: branchCode ?? this.branchCode,
      customerName: customerName ?? this.customerName,
      customerWa: customerWa ?? this.customerWa,
    );
  }
}

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final StoreInfo storeInfo;

  const SettingsLoaded({required this.storeInfo});

  @override
  List<Object?> get props => [storeInfo];
}

class SettingsUpdating extends SettingsState {}

class SettingsUpdated extends SettingsState {
  final String message;
  final StoreInfo storeInfo;

  const SettingsUpdated({
    required this.message,
    required this.storeInfo,
  });

  @override
  List<Object?> get props => [message, storeInfo];
}

class SettingsError extends SettingsState {
  final String message;

  const SettingsError({required this.message});

  @override
  List<Object?> get props => [message];
}
