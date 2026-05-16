import 'package:equatable/equatable.dart';
import 'package:kreatif_klinik/data/models/product.dart';
import 'package:kreatif_klinik/data/models/product_unit.dart';

class CartItem extends Equatable {
  final Product product;
  final double quantity;
  final int discount;
  final String? note;
  final ProductUnit? selectedUnit;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.discount = 0,
    this.note,
    this.selectedUnit,
  });

  int get effectivePrice => selectedUnit?.price ?? product.price;
  int get grossTotal => (effectivePrice * quantity).round();
  int get subtotal {
    return grossTotal - discount;
  }

  CartItem copyWith({
    Product? product,
    double? quantity,
    int? discount,
    String? note,
    ProductUnit? selectedUnit,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      note: note ?? this.note,
      selectedUnit: selectedUnit ?? this.selectedUnit,
    );
  }

  @override
  List<Object?> get props => [product, quantity, discount, note, selectedUnit];
}
