import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/data/repositories/registration_repository.dart';
import 'package:kreatif_klinik/data/models/registration.dart';
import 'package:kreatif_klinik/logic/cubits/registration/registration_state.dart';

class RegistrationCubit extends Cubit<RegistrationState> {
  final RegistrationRepository _repository;

  RegistrationCubit(this._repository) : super(RegistrationInitial());

  Future<void> loadRegistrations() async {
    emit(RegistrationLoading());
    try {
      final registrations = await _repository.getAllRegistrations();
      emit(RegistrationLoaded(registrations));
    } catch (e) {
      emit(RegistrationError(e.toString()));
    }
  }

  Future<void> addRegistration(Registration registration) async {
    try {
      await _repository.createRegistration(registration);
      loadRegistrations();
    } catch (e) {
      emit(RegistrationError(e.toString()));
    }
  }

  Future<void> updateStatus(int id, String status) async {
    try {
      await _repository.updateRegistrationStatus(id, status);
      loadRegistrations();
    } catch (e) {
      emit(RegistrationError(e.toString()));
    }
  }

  Future<void> deleteRegistration(int id) async {
    try {
      await _repository.deleteRegistration(id);
      loadRegistrations();
    } catch (e) {
      emit(RegistrationError(e.toString()));
    }
  }

  Future<String> getNextRegistrationNo() async {
    try {
      return await _repository.generateNextRegistrationNo();
    } catch (e) {
      throw Exception('Gagal men-generate nomor registrasi: $e');
    }
  }
}
