import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/data/models/stock_transfer.dart';
import 'package:kreatif_otopart/data/repositories/stock_transfer_repository.dart';
import 'package:kreatif_otopart/logic/cubits/stock_transfer/stock_transfer_state.dart';

class StockTransferCubit extends Cubit<StockTransferState> {
  final StockTransferRepository _repository;

  StockTransferCubit({StockTransferRepository? repository})
      : _repository = repository ?? StockTransferRepository(),
        super(StockTransferInitial());

  Future<void> loadTransfers() async {
    emit(StockTransferLoading());
    try {
      final transfers = await _repository.getStockTransfers();
      emit(StockTransferLoaded(transfers));
    } catch (e) {
      emit(StockTransferError('Gagal memuat riwayat transfer: ${e.toString()}'));
    }
  }

  Future<void> createTransfer(StockTransfer transfer) async {
    emit(StockTransferLoading());
    try {
      await _repository.createTransfer(transfer);
      emit(const StockTransferActionSuccess('Transfer stok berhasil'));
      loadTransfers();
    } catch (e) {
      emit(StockTransferError('Gagal melakukan transfer stok: ${e.toString()}'));
    }
  }
}
