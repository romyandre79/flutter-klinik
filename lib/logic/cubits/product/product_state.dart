import 'package:equatable/equatable.dart';
import 'package:kreatif_klinik/data/models/product.dart';

abstract class ProductState extends Equatable {
  const ProductState();

  @override
  List<Object?> get props => [];
}

class ProductInitial extends ProductState {}

class ProductLoading extends ProductState {}

class ProductLoaded extends ProductState {
  final List<Product> products;

  const ProductLoaded(this.products);
  
  List<Product> get serviceList => products.where((p) => p.isService).toList();
  List<Product> get goodsList => products.where((p) => p.isGoods).toList();

  @override
  List<Object?> get props => [products];
}

class ProductOperationSuccess extends ProductState {
  final String message;

  const ProductOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ProductError extends ProductState {
  final String message;

  const ProductError(this.message);

  @override
  List<Object?> get props => [message];
}
