import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/core/services/import_service.dart';
import 'package:kreatif_pos/data/models/customer.dart';
import 'package:kreatif_pos/data/repositories/customer_repository.dart';
import 'package:kreatif_pos/logic/cubits/customer/customer_state.dart';

class CustomerCubit extends Cubit<CustomerState> {
  final CustomerRepository _customerRepository;
  List<Customer> _customers = [];

  CustomerCubit({CustomerRepository? customerRepository})
      : _customerRepository = customerRepository ?? CustomerRepository(),
        super(const CustomerInitial());

  List<Customer> get customers => _customers;

  /// Load all customers
  Future<void> loadCustomers() async {
    emit(const CustomerLoading());

    try {
      _customers = await _customerRepository.getAllCustomers();
      emit(CustomerLoaded(_customers));
    } catch (e) {
      emit(CustomerError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Search customers
  Future<void> searchCustomers(String query) async {
    emit(const CustomerLoading());

    try {
      if (query.trim().isEmpty) {
        await loadCustomers();
        return;
      }

      _customers = await _customerRepository.searchCustomers(query);
      emit(CustomerLoaded(_customers));
    } catch (e) {
      emit(CustomerError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Create customer
  Future<void> createCustomer(Customer customer) async {
    emit(const CustomerLoading());

    try {
      final created = await _customerRepository.createCustomer(customer);
      emit(CustomerOperationSuccess('Customer berhasil ditambahkan', customer: created));
      await loadCustomers();
    } catch (e) {
      emit(CustomerError(e.toString().replaceAll('Exception: ', '')));
      emit(CustomerLoaded(_customers));
    }
  }

  /// Update customer
  Future<void> updateCustomer(Customer customer) async {
    emit(const CustomerLoading());

    try {
      await _customerRepository.updateCustomer(customer);
      emit(const CustomerOperationSuccess('Customer berhasil diupdate'));
      await loadCustomers();
    } catch (e) {
      emit(CustomerError(e.toString().replaceAll('Exception: ', '')));
      emit(CustomerLoaded(_customers));
    }
  }

  /// Delete customer
  Future<void> deleteCustomer(int id) async {
    emit(const CustomerLoading());

    try {
      await _customerRepository.deleteCustomer(id);
      emit(const CustomerOperationSuccess('Customer berhasil dihapus'));
      await loadCustomers();
    } catch (e) {
      emit(CustomerError(e.toString().replaceAll('Exception: ', '')));
      emit(CustomerLoaded(_customers));
    }
  }

  Future<void> importCustomers(File file) async {
    emit(const CustomerLoading());
    try {
      final customers = await ImportService().parseCustomersFromExcel(file);
      if (customers.isEmpty) {
        emit(const CustomerError('Tidak ada data customer yang ditemukan'));
        emit(CustomerLoaded(_customers));
        return;
      }
      await _customerRepository.addCustomers(customers);
      emit(const CustomerOperationSuccess('Berhasil mengimpor customer'));
      await loadCustomers();
    } catch (e) {
      emit(CustomerError(e.toString().replaceAll('Exception: ', '')));
      emit(CustomerLoaded(_customers));
    }
  }
}
