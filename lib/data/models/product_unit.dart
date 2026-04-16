import 'package:equatable/equatable.dart';

class ProductUnit extends Equatable {
  final int? id;
  final int productId;
  final String unitName;
  final int price;
  final int cost;
  final int? parentUnitId;
  final double multiplier; // How many of THIS unit are in 1 PARENT unit
  final double stock; // Physical stock of THIS specific unit

  const ProductUnit({
    this.id,
    required this.productId,
    required this.unitName,
    required this.price,
    this.cost = 0,
    this.parentUnitId,
    this.multiplier = 1.0,
    this.stock = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'unit_name': unitName,
      'price': price,
      'cost': cost,
      'parent_unit_id': parentUnitId,
      'multiplier': multiplier,
      'stock': stock,
    };
  }

  factory ProductUnit.fromMap(Map<String, dynamic> map) {
    return ProductUnit(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      unitName: map['unit_name'] as String,
      price: map['price'] as int,
      cost: (map['cost'] as int?) ?? 0,
      parentUnitId: map['parent_unit_id'] as int?,
      multiplier: (map['multiplier'] as num).toDouble(),
      stock: (map['stock'] as num).toDouble(),
    );
  }

  ProductUnit copyWith({
    int? id,
    int? productId,
    String? unitName,
    int? price,
    int? cost,
    int? parentUnitId,
    double? multiplier,
    double? stock,
  }) {
    return ProductUnit(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitName: unitName ?? this.unitName,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      parentUnitId: parentUnitId ?? this.parentUnitId,
      multiplier: multiplier ?? this.multiplier,
      stock: stock ?? this.stock,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        unitName,
        price,
        cost,
        parentUnitId,
        multiplier,
        stock,
      ];
}
