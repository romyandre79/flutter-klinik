import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/core/services/import_service.dart';
import 'package:kreatif_pos/data/models/supplier.dart';
import 'package:kreatif_pos/data/repositories/supplier_repository.dart';
import 'package:kreatif_pos/logic/cubits/supplier/supplier_state.dart';

class SupplierCubit extends Cubit<SupplierState> {
  final SupplierRepository _supplierRepository;

  SupplierCubit({required SupplierRepository supplierRepository})
      : _supplierRepository = supplierRepository,
        super(SupplierInitial());

  Future<void> loadSuppliers() async {
    try {
      emit(SupplierLoading());
      final suppliers = await _supplierRepository.getAllSuppliers();
      emit(SupplierLoaded(suppliers));
    } catch (e) {
      emit(SupplierError('Failed to load suppliers: ${e.toString()}'));
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    try {
      emit(SupplierLoading());
      await _supplierRepository.createSupplier(supplier);
      emit(const SupplierOperationSuccess('Supplier added successfully'));
      loadSuppliers(); // Reload list
    } catch (e) {
      emit(SupplierError('Failed to add supplier: ${e.toString()}'));
    }
  }

  Future<void> updateSupplier(Supplier supplier) async {
    try {
      emit(SupplierLoading());
      await _supplierRepository.updateSupplier(supplier);
      emit(const SupplierOperationSuccess('Supplier updated successfully'));
      loadSuppliers(); // Reload list
    } catch (e) {
      emit(SupplierError('Failed to update supplier: ${e.toString()}'));
    }
  }

  Future<void> deleteSupplier(int id) async {
    try {
      emit(SupplierLoading());
      await _supplierRepository.deleteSupplier(id);
      emit(const SupplierOperationSuccess('Supplier deleted successfully'));
      loadSuppliers(); // Reload list
    } catch (e) {
      emit(SupplierError('Failed to delete supplier: ${e.toString()}'));
    }
  }

  Future<void> importSuppliers(File file) async {
    try {
      emit(SupplierLoading());
      final suppliers = await ImportService().parseSuppliersFromExcel(file);
      if (suppliers.isEmpty) {
        emit(SupplierError('No supplier data found'));
        await loadSuppliers();
        return;
      }
      await _supplierRepository.addSuppliers(suppliers);
      emit(const SupplierOperationSuccess('Suppliers imported successfully'));
      await loadSuppliers();
    } catch (e) {
      emit(SupplierError('Failed to import suppliers: ${e.toString()}'));
       await loadSuppliers();
    }
  }
}
