import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/core/services/import_service.dart';
import 'package:kreatif_klinik/data/models/product.dart';
import 'package:kreatif_klinik/data/repositories/product_repository.dart';
import 'package:kreatif_klinik/logic/cubits/product/product_state.dart';
import 'package:kreatif_klinik/core/constants/app_constants.dart';

class ProductCubit extends Cubit<ProductState> {
  final ProductRepository _productRepository;
  List<Product> _products = [];

  ProductCubit(this._productRepository) : super(ProductInitial());
  
  List<Product> get products => _products;

  Future<void> loadProducts({ProductType? type, bool activeOnly = true, String? query}) async {
    emit(ProductLoading());
    try {
      _products = await _productRepository.getProducts(type: type, activeOnly: activeOnly, query: query);
      emit(ProductLoaded(_products));
    } catch (e) {
      emit(ProductError('Gagal memuat data: ${e.toString()}'));
    }
  }

  Future<void> addProduct(Product product) async {
    if (AppConstants.isDemoMode && _products.length >= 5) {
      emit(const ProductError('Anda telah melebihi batas transaksi aplikasi demo, silakan beli hubungi Sales Kreatif atau ke 081932701147'));
      emit(ProductLoaded(_products));
      return;
    }
    emit(ProductLoading());
    try {
      await _productRepository.addProduct(product);
      await loadProducts(); // Reload
      emit(ProductLoaded(_products)); // Emit loaded first to show list
      emit(const ProductOperationSuccess('Berhasil menambahkan item'));
      emit(ProductLoaded(_products)); // Re-emit loaded state
    } catch (e) {
      emit(ProductError('Gagal menambahkan item: ${e.toString()}'));
      emit(ProductLoaded(_products)); // Return to loaded state on error
    }
  }

  Future<void> updateProduct(Product product) async {
    emit(ProductLoading());
    try {
      await _productRepository.updateProduct(product);
      await loadProducts();
      emit(ProductLoaded(_products));
      emit(const ProductOperationSuccess('Berhasil memperbarui item'));
      emit(ProductLoaded(_products));
    } catch (e) {
      emit(ProductError('Gagal memperbarui item: ${e.toString()}'));
      emit(ProductLoaded(_products));
    }
  }

  Future<void> deleteProduct(int id) async {
    emit(ProductLoading());
    try {
      await _productRepository.deleteProduct(id);
      await loadProducts();
      emit(ProductLoaded(_products));
      emit(const ProductOperationSuccess('Berhasil menghapus item'));
      emit(ProductLoaded(_products));
    } catch (e) {
      emit(ProductError('Gagal menghapus item: ${e.toString()}'));
      emit(ProductLoaded(_products));
    }
  }

  Future<void> importProducts() async {
    // 1. Pick file
    // Note: We need to handle file picking here or in UI. 
    // Usually Cubit should receive the file or file path, but for simplicity we can use FilePicker here 
    // or better, let UI pick and pass the file.
    // However, to keep logic in Cubit, we can do it here if we impart 'UI-free' logic or inject a service.
    // But since FilePicker is a plugin, it's fine to use it here or in UI.
    // Let's assume UI handles picking to keep Cubit clean from UI plugins if possible, 
    // but often it's convenient to put it here.
    // Let's modify this to receive a File object to be more testable and clean.
  }
  
  Future<void> importProductsFromFile(File file) async {
    emit(ProductLoading());
    try {
      // 2. Parse
      final products = await ImportService().parseProductsFromExcel(file);
      
      if (products.isEmpty) {
        emit(const ProductError('Tidak ada data produk yang ditemukan dalam file'));
        emit(ProductLoaded(_products));
        return;
      }

      // 3. Save
      await _productRepository.addProducts(products);
      
      // 4. Reload
      await loadProducts();
      emit(const ProductOperationSuccess('Berhasil mengimpor produk'));
      emit(ProductLoaded(_products));
    } catch (e) {
      emit(ProductError('Gagal mengimpor produk: ${e.toString()}'));
      emit(ProductLoaded(_products));
    }
  }
}
