import 'package:equatable/equatable.dart';
import 'package:kreatif_pos/data/models/cart_item.dart';
import 'package:kreatif_pos/data/models/product.dart';
import 'package:kreatif_pos/data/models/customer.dart';

abstract class PosState extends Equatable {
  const PosState();

  @override
  List<Object?> get props => [];
}

class PosInitial extends PosState {}

class PosLoading extends PosState {}

class PosLoaded extends PosState {
  final List<Product> products;
  final List<Product> filteredProducts;
  final List<CartItem> cartItems;
  final String selectedCategory; // 'All', 'Kiloan', 'Satuan', 'Barang', 'Jasa'
  final String searchQuery;
  final Customer? selectedCustomer;
  final String customerName;
  final int orderDiscount;

  const PosLoaded({
    this.products = const [],
    this.filteredProducts = const [],
    this.cartItems = const [],
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.selectedCustomer,
    this.customerName = 'Walk-in Customer',
    this.orderDiscount = 0,
  });

  int get totalAmount => cartItems.fold(0, (sum, item) => sum + (item.effectivePrice * item.quantity).round());
  int get totalItems => cartItems.fold(0, (sum, item) => sum + item.quantity.round());
  int get totalItemDiscount => cartItems.fold(0, (sum, item) => sum + item.discount);
  int get totalDiscount => totalItemDiscount + orderDiscount;
  int get grandTotal => totalAmount - totalDiscount;

  // Sentinel so callers can explicitly pass null to clear selectedCustomer.
  static const _absent = Object();

  PosLoaded copyWith({
    List<Product>? products,
    List<Product>? filteredProducts,
    List<CartItem>? cartItems,
    String? selectedCategory,
    String? searchQuery,
    Object? selectedCustomer = _absent,
    String? customerName,
    int? orderDiscount,
  }) {
    return PosLoaded(
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      cartItems: cartItems ?? this.cartItems,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCustomer: selectedCustomer == _absent
          ? this.selectedCustomer
          : selectedCustomer as Customer?,
      customerName: customerName ?? this.customerName,
      orderDiscount: orderDiscount ?? this.orderDiscount,
    );
  }

  @override
  List<Object?> get props => [
        products,
        filteredProducts,
        cartItems,
        selectedCategory,
        searchQuery,
        selectedCustomer,
        customerName,
        orderDiscount,
      ];
}

class PosError extends PosState {
  final String message;

  const PosError(this.message);

  @override
  List<Object?> get props => [message];
}

class PosSuccess extends PosState {
  final String message; 

  const PosSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
