import 'package:equatable/equatable.dart';
import 'package:kreatif_otopart/data/models/stock_transfer.dart';

abstract class StockTransferState extends Equatable {
  const StockTransferState();

  @override
  List<Object?> get props => [];
}

class StockTransferInitial extends StockTransferState {}

class StockTransferLoading extends StockTransferState {}

class StockTransferLoaded extends StockTransferState {
  final List<StockTransfer> transfers;
  const StockTransferLoaded(this.transfers);

  @override
  List<Object?> get props => [transfers];
}

class StockTransferActionSuccess extends StockTransferState {
  final String message;
  const StockTransferActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class StockTransferError extends StockTransferState {
  final String message;
  const StockTransferError(this.message);

  @override
  List<Object?> get props => [message];
}
