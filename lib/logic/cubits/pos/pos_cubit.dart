import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/data/models/cart_item.dart';
import 'package:kreatif_pos/data/models/product.dart';
import 'package:kreatif_pos/data/models/product_unit.dart';
import 'package:kreatif_pos/data/models/customer.dart';
import 'package:kreatif_pos/data/repositories/product_repository.dart';
import 'package:kreatif_pos/logic/cubits/pos/pos_state.dart';

class PosCubit extends Cubit<PosState> {
  final ProductRepository _productRepository;

  PosCubit(this._productRepository) : super(PosInitial()) {
    // Optionally load products immediately, but explicit call is safer for now
    // loadProducts();
    // No, dashboard calls loadProducts().
  }

  // Load products from repository
  Future<void> loadProducts() async {
    emit(PosLoading());
    try {
      final products = await _productRepository.getProducts();
      emit(PosLoaded(
        products: products,
        filteredProducts: products, // Initially show all
      ));
    } catch (e) {
      emit(const PosError('Failed to load products'));
    }
  }

  // Get available categories (unique units)
  List<String> get availableCategories {
    if (state is PosLoaded) {
      final products = (state as PosLoaded).products;
      final units = products.map((p) => p.unit).toSet().toList();
      units.sort();
      return units; // Returns ['kg', 'pcs', 'pack', etc.]
    }
    return [];
  }

  // Filter products by query or category
  void filterProducts({String? query, String? category}) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      
      String currentQuery = query ?? currentState.searchQuery;
      String currentCategory = category ?? currentState.selectedCategory;

      List<Product> filtered = currentState.products.where((product) {
        bool matchesQuery = product.name.toLowerCase().contains(currentQuery.toLowerCase()) ||
            (product.barcode != null && product.barcode!.toLowerCase().contains(currentQuery.toLowerCase()));
        bool matchesCategory = true;

          if (currentCategory == 'Kiloan') {
            matchesCategory = product.unit.toLowerCase() == 'kg';
          } else if (currentCategory == 'Satuan') {
            matchesCategory = product.unit.toLowerCase() != 'kg';
          }
        
        return matchesQuery && matchesCategory;
      }).toList();

      emit(currentState.copyWith(
        filteredProducts: filtered,
        searchQuery: currentQuery,
        selectedCategory: currentCategory,
      ));
    }
  }

  // Add product to cart
  void addToCart(Product product, {ProductUnit? unit}) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      final currentCart = List<CartItem>.from(currentState.cartItems);

      // Default to base unit if not provided
      final selectedUnit = unit ?? product.baseUnit;
      final unitId = selectedUnit?.id;

      // Check if product with SAME unit already in cart
      final existingIndex = currentCart.indexWhere((item) => 
          item.product.id == product.id && item.selectedUnit?.id == unitId);

      if (existingIndex >= 0) {
        // Increment quantity
        final existingItem = currentCart[existingIndex];
        final newQuantity = existingItem.quantity + 1;
        
        // Recalculate discount for the new quantity if customer has default discount
        int newDiscount = existingItem.discount;
        if (currentState.selectedCustomer != null && currentState.selectedCustomer!.defaultDiscount > 0) {
           final double basePrice = (existingItem.selectedUnit?.price ?? existingItem.product.price).toDouble();
           newDiscount = (basePrice * newQuantity * currentState.selectedCustomer!.defaultDiscount / 100).round();
        }

        currentCart[existingIndex] = existingItem.copyWith(
          quantity: newQuantity,
          discount: newDiscount,
        );
      } else {
        // Add new item
        int discountAmount = 0;
        final basePrice = selectedUnit?.price ?? product.price;
        
        if (currentState.selectedCustomer != null && currentState.selectedCustomer!.defaultDiscount > 0) {
          discountAmount = (basePrice * 1 * currentState.selectedCustomer!.defaultDiscount / 100).round();
        }

        currentCart.add(CartItem(
          product: product,
          quantity: 1,
          discount: discountAmount, // For qty 1, total line discount == per unit discount
          selectedUnit: selectedUnit,
        ));
      }

      emit(currentState.copyWith(cartItems: currentCart));
    }
  }

  // Update unit for an item in cart
  void updateUnit(CartItem item, ProductUnit unit) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      final currentCart = List<CartItem>.from(currentState.cartItems);

      final index = currentCart.indexOf(item);
      if (index >= 0) {
        // When changing unit, we might want to reset or recalculate discount
        int newDiscount = 0;
        if (currentState.selectedCustomer != null && currentState.selectedCustomer!.defaultDiscount > 0) {
          newDiscount = (unit.price * currentState.selectedCustomer!.defaultDiscount / 100).round();
        }

        currentCart[index] = item.copyWith(
          selectedUnit: unit,
          discount: (newDiscount * item.quantity).round(),
        );
        emit(currentState.copyWith(cartItems: currentCart));
      }
    }
  }

  // Remove item from cart (decrement or remove)
  void removeFromCart(CartItem item) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      final currentCart = List<CartItem>.from(currentState.cartItems);

      final index = currentCart.indexOf(item);
      if (index >= 0) {
        if (currentCart[index].quantity > 1) {
          final newQuantity = currentCart[index].quantity - 1;
          
          // Recalculate discount for the new quantity if customer has default discount
          int newDiscount = currentCart[index].discount;
          if (currentState.selectedCustomer != null && currentState.selectedCustomer!.defaultDiscount > 0) {
             final double basePrice = currentCart[index].effectivePrice.toDouble();
             newDiscount = (basePrice * newQuantity * currentState.selectedCustomer!.defaultDiscount / 100).round();
          }

          currentCart[index] = currentCart[index].copyWith(
            quantity: newQuantity,
            discount: newDiscount,
          );
        } else {
          currentCart.removeAt(index);
        }
        emit(currentState.copyWith(cartItems: currentCart));
      }
    }
  }

  // Clear entire cart
  void clearCart() {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      emit(currentState.copyWith(
        cartItems: [],
        orderDiscount: 0,
        selectedCustomer: null,
        customerName: 'Walk-in Customer',
      ));
    }
  }

  // Select a customer
  void selectCustomer(Customer? customer) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      
      // Update all cart items with the new default discount
      final currentCart = List<CartItem>.from(currentState.cartItems);
      final double discountPercent = customer?.defaultDiscount ?? 0;
      
      for (int i = 0; i < currentCart.length; i++) {
        final double basePrice = (currentCart[i].selectedUnit?.price ?? currentCart[i].product.price).toDouble();
        final int totalDiscount = (basePrice * currentCart[i].quantity * discountPercent / 100).round();
        currentCart[i] = currentCart[i].copyWith(discount: totalDiscount);
      }

      emit(currentState.copyWith(
        selectedCustomer: customer,
        customerName: customer?.name ?? 'Walk-in Customer',
        cartItems: currentCart,
      ));
    }
  }

  // Set customer name (free text)
  void setCustomerName(String name) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      emit(currentState.copyWith(
        customerName: name,
        selectedCustomer: null, // Reset selected object if name changes manually
      ));
    }
  }

  // Update quantity directly
  void updateQuantity(CartItem item, double quantity) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      final currentCart = List<CartItem>.from(currentState.cartItems);

      final index = currentCart.indexOf(item);
      if (index >= 0) {
        if (quantity <= 0) {
          currentCart.removeAt(index);
        } else {
          // If customer has default discount, recalculate it for the new quantity
          int newDiscount = currentCart[index].discount;
          if (currentState.selectedCustomer != null && currentState.selectedCustomer!.defaultDiscount > 0) {
             final double basePrice = currentCart[index].effectivePrice.toDouble();
             newDiscount = (basePrice * quantity * currentState.selectedCustomer!.defaultDiscount / 100).round();
          }
          currentCart[index] = currentCart[index].copyWith(
            quantity: quantity,
            discount: newDiscount,
          );
        }
        emit(currentState.copyWith(cartItems: currentCart));
      }
    }
  }

  // Update item discount in Rupiah (Total line discount)
  void updateItemDiscount(CartItem item, int discountAmount) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      final currentCart = List<CartItem>.from(currentState.cartItems);

      final index = currentCart.indexOf(item);
      if (index >= 0) {
        currentCart[index] = currentCart[index].copyWith(discount: discountAmount);
        emit(currentState.copyWith(cartItems: currentCart));
      }
    }
  }

  // Update order-level discount in Rupiah
  void updateOrderDiscount(int discountAmount) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      emit(currentState.copyWith(orderDiscount: discountAmount));
    }
  }
}
