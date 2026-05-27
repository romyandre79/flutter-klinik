import 'package:equatable/equatable.dart';
import 'package:kreatif_otopart/data/models/pengumuman_template.dart';

abstract class PengumumanState extends Equatable {
  const PengumumanState();

  @override
  List<Object?> get props => [];
}

class PengumumanInitial extends PengumumanState {}

class PengumumanLoading extends PengumumanState {}

class PengumumanLoaded extends PengumumanState {
  final List<PengumumanTemplate> templates;

  const PengumumanLoaded(this.templates);

  @override
  List<Object?> get props => [templates];
}

class PengumumanError extends PengumumanState {
  final String message;

  const PengumumanError(this.message);

  @override
  List<Object?> get props => [message];
}

class PengumumanActionSuccess extends PengumumanState {
  final String message;

  const PengumumanActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
