import 'package:equatable/equatable.dart';
import 'package:kreatif_klinik/data/models/unit.dart';

abstract class UnitState extends Equatable {
  const UnitState();

  @override
  List<Object?> get props => [];
}

class UnitInitial extends UnitState {}

class UnitLoading extends UnitState {}

class UnitLoaded extends UnitState {
  final List<Unit> units;

  const UnitLoaded(this.units);

  @override
  List<Object?> get props => [units];
}

class UnitOperationSuccess extends UnitState {
  final String message;
  final List<Unit> units;

  const UnitOperationSuccess(this.message, this.units);

  @override
  List<Object?> get props => [message, units];
}

class UnitError extends UnitState {
  final String message;

  const UnitError(this.message);

  @override
  List<Object?> get props => [message];
}
