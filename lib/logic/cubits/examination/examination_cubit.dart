import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/data/repositories/examination_repository.dart';
import 'package:kreatif_klinik/data/repositories/registration_repository.dart';
import 'package:kreatif_klinik/data/models/examination.dart';
import 'package:kreatif_klinik/logic/cubits/examination/examination_state.dart';

class ExaminationCubit extends Cubit<ExaminationState> {
  final ExaminationRepository _examinationRepository;
  final RegistrationRepository _registrationRepository;

  ExaminationCubit({
    required ExaminationRepository examinationRepository,
    required RegistrationRepository registrationRepository,
  })  : _examinationRepository = examinationRepository,
        _registrationRepository = registrationRepository,
        super(ExaminationInitial());

  Future<void> loadExamination(int registrationId) async {
    emit(ExaminationLoading());
    try {
      final exam = await _examinationRepository.getExaminationByRegistrationId(registrationId);
      emit(ExaminationLoaded(exam));
    } catch (e) {
      emit(ExaminationError(e.toString()));
    }
  }

  Future<void> saveExamination(Examination examination) async {
    emit(ExaminationLoading());
    try {
      final savedExam = await _examinationRepository.saveExamination(examination);
      // Auto-update registration status to completed
      await _registrationRepository.updateRegistrationStatus(examination.registrationId, 'completed');
      emit(ExaminationSaved(savedExam));
    } catch (e) {
      emit(ExaminationError(e.toString()));
    }
  }
}
