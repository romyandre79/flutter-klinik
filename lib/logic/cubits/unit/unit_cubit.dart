import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/data/models/unit.dart';
import 'package:kreatif_pos/data/repositories/unit_repository.dart';
import 'package:kreatif_pos/logic/cubits/unit/unit_state.dart';

class UnitCubit extends Cubit<UnitState> {
  final UnitRepository _repository;

  UnitCubit(this._repository) : super(UnitInitial());

  Future<void> loadUnits() async {
    try {
      emit(UnitLoading());
      final units = await _repository.getUnits();
      emit(UnitLoaded(units));
    } catch (e) {
      emit(UnitError('Gagal memuat data satuan: $e'));
    }
  }

  Future<void> addUnit(String name) async {
    try {
      emit(UnitLoading());
      final unit = Unit(name: name);
      await _repository.addUnit(unit);
      final units = await _repository.getUnits();
      emit(UnitOperationSuccess('Satuan berhasil ditambahkan', units));
    } catch (e) {
      emit(UnitError('Gagal menambah satuan: $e'));
    }
  }

  Future<void> updateUnit(Unit unit) async {
    try {
      emit(UnitLoading());
      await _repository.updateUnit(unit);
      final units = await _repository.getUnits();
      emit(UnitOperationSuccess('Satuan berhasil diubah', units));
    } catch (e) {
      emit(UnitError('Gagal mengubah satuan: $e'));
    }
  }

  Future<void> deleteUnit(int id) async {
    try {
      emit(UnitLoading());
      await _repository.deleteUnit(id);
      final units = await _repository.getUnits();
      emit(UnitOperationSuccess('Satuan berhasil dihapus', units));
    } catch (e) {
      emit(UnitError('Gagal menghapus satuan: $e'));
    }
  }
}
