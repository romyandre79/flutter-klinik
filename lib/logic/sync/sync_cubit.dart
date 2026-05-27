import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/core/services/sync_service.dart';
import 'package:kreatif_otopart/logic/sync/sync_state.dart';

class SyncCubit extends Cubit<SyncState> {
  final SyncService _syncService;

  SyncCubit(this._syncService) : super(SyncInitial());

  Future<void> syncData() async {
    emit(const SyncLoading('Syncing data...'));
    try {
      emit(const SyncLoading('Uploading sales...'));
      final uploadedCount = await _syncService.uploadOrders();
      
      emit(const SyncLoading('Uploading purchasing...'));
      final poCount = await _syncService.uploadPurchaseOrders();
      
      emit(const SyncLoading('Downloading master data...'));
      await _syncService.downloadMasterData();
      
      emit(SyncSuccess('Sinkronisasi selesai. ${uploadedCount + poCount} transaksi terkirim.'));
    } catch (e) {
      emit(SyncFailure(e.toString()));
    }
  }

  Future<void> uploadTransactions() async {
    emit(const SyncLoading('Uploading transactions...'));
    try {
      final uploadedCount = await _syncService.uploadOrders();
      emit(SyncSuccess('Berhasil mengirim $uploadedCount transaksi.'));
    } catch (e) {
      emit(SyncFailure(e.toString()));
    }
  }

  Future<void> downloadMasterData() async {
    emit(const SyncLoading('Downloading master data...'));
    try {
      await _syncService.downloadMasterData();
      emit(const SyncSuccess('Data master berhasil diperbarui.'));
    } catch (e) {
      emit(SyncFailure(e.toString()));
    }
  }
}
