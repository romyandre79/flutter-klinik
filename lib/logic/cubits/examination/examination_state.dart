import 'package:equatable/equatable.dart';
import 'package:kreatif_klinik/data/models/examination.dart';

abstract class ExaminationState extends Equatable {
  const ExaminationState();

  @override
  List<Object?> get props => [];
}

class ExaminationInitial extends ExaminationState {}

class ExaminationLoading extends ExaminationState {}

class ExaminationLoaded extends ExaminationState {
  final Examination? examination;

  const ExaminationLoaded(this.examination);

  @override
  List<Object?> get props => [examination];
}

class ExaminationSaved extends ExaminationState {
  final Examination examination;

  const ExaminationSaved(this.examination);

  @override
  List<Object?> get props => [examination];
}

class ExaminationError extends ExaminationState {
  final String message;

  const ExaminationError(this.message);

  @override
  List<Object?> get props => [message];
}
