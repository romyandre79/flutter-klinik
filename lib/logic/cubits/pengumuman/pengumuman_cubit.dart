import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/data/models/pengumuman_template.dart';
import 'package:kreatif_otopart/data/repositories/pengumuman_template_repository.dart';
import 'package:kreatif_otopart/logic/cubits/pengumuman/pengumuman_state.dart';

class PengumumanCubit extends Cubit<PengumumanState> {
  final PengumumanTemplateRepository _repository;

  PengumumanCubit({PengumumanTemplateRepository? repository})
      : _repository = repository ?? PengumumanTemplateRepository(),
        super(PengumumanInitial());

  Future<void> loadTemplates({String? type}) async {
    emit(PengumumanLoading());
    try {
      final templates = await _repository.getTemplates(type: type);
      emit(PengumumanLoaded(templates));
    } catch (e) {
      emit(PengumumanError('Gagal memuat template: ${e.toString()}'));
    }
  }

  Future<void> addTemplate(PengumumanTemplate template) async {
    try {
      await _repository.addTemplate(template);
      emit(const PengumumanActionSuccess('Template berhasil ditambah'));
      loadTemplates();
    } catch (e) {
      emit(PengumumanError('Gagal menambah template: ${e.toString()}'));
    }
  }

  Future<void> updateTemplate(PengumumanTemplate template) async {
    try {
      await _repository.updateTemplate(template);
      emit(const PengumumanActionSuccess('Template berhasil diperbarui'));
      loadTemplates();
    } catch (e) {
      emit(PengumumanError('Gagal memperbarui template: ${e.toString()}'));
    }
  }

  Future<void> deleteTemplate(int id) async {
    try {
      await _repository.deleteTemplate(id);
      emit(const PengumumanActionSuccess('Template berhasil dihapus'));
      loadTemplates();
    } catch (e) {
      emit(PengumumanError('Gagal menghapus template: ${e.toString()}'));
    }
  }
}
