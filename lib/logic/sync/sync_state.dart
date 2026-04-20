import 'package:equatable/equatable.dart';

abstract class SyncState extends Equatable {
  const SyncState();

  @override
  List<Object?> get props => [];
}

class SyncInitial extends SyncState {}

class SyncLoading extends SyncState {
  final String message;
  final double? progress;

  const SyncLoading(this.message, {this.progress});

  @override
  List<Object?> get props => [message, progress];
}

class SyncSuccess extends SyncState {
  final String message;

  const SyncSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class SyncFailure extends SyncState {
  final String error;

  const SyncFailure(this.error);

  @override
  List<Object?> get props => [error];
}
