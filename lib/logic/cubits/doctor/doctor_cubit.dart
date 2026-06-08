import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/data/repositories/doctor_repository.dart';
import 'package:kreatif_klinik/data/models/doctor.dart';
import 'package:kreatif_klinik/logic/cubits/doctor/doctor_state.dart';

class DoctorCubit extends Cubit<DoctorState> {
  final DoctorRepository _repository;

  DoctorCubit(this._repository) : super(DoctorInitial());

  Future<void> loadDoctors() async {
    emit(DoctorLoading());
    try {
      final doctors = await _repository.getAllDoctors();
      emit(DoctorLoaded(doctors));
    } catch (e) {
      emit(DoctorError(e.toString()));
    }
  }

  Future<void> addDoctor(Doctor doctor) async {
    try {
      await _repository.createDoctor(doctor);
      loadDoctors();
    } catch (e) {
      emit(DoctorError(e.toString()));
    }
  }

  Future<void> updateDoctor(Doctor doctor) async {
    try {
      await _repository.updateDoctor(doctor);
      loadDoctors();
    } catch (e) {
      emit(DoctorError(e.toString()));
    }
  }

  Future<void> deleteDoctor(int id) async {
    try {
      await _repository.deleteDoctor(id);
      loadDoctors();
    } catch (e) {
      emit(DoctorError(e.toString()));
    }
  }
}
