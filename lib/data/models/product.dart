import 'package:equatable/equatable.dart';
import 'package:kreatif_klinik/data/models/product_unit.dart';

enum ProductType { service, goods }

extension ProductTypeExtension on ProductType {
  String get value {
    switch (this) {
      case ProductType.service:
        return 'service';
      case ProductType.goods:
        return 'goods';
    }
  }

  String get displayName {
    switch (this) {
      case ProductType.service:
        return 'Jasa / Layanan';
      case ProductType.goods:
        return 'Barang / Produk';
    }
  }

  static ProductType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'service':
        return ProductType.service;
      case 'goods':
        return ProductType.goods;
      default:
        return ProductType.goods;
    }
  }
}

class Product extends Equatable {
  final int? id;
  final String name;
  final String? description;
  final int price;
  final int cost; // Harga beli / modal
  final double? stock; // Nullable for services
  final String unit; // kg, pcs, pack, etc.
  final ProductType type;
  final int? durationDays; // Only for services
  final int expireDays; // New field for expiration
  final String? imageUrl;
  final String? barcode; // New field for barcode
  final bool isActive;
  final int? serverId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ProductUnit> units;

  const Product({
    this.id,
    required this.name,
    this.description,
    required this.price,
    this.cost = 0,
    this.stock,
    required this.unit,
    required this.type,
    this.durationDays,
    this.expireDays = 0,
    this.imageUrl,
    this.barcode,
    this.isActive = true,
    this.serverId,
    this.createdAt,
    this.updatedAt,
    this.units = const [],
  });

  ProductUnit? get baseUnit {
    if (units.isEmpty) return null;
    try {
      return units.firstWhere((u) => u.parentUnitId == null);
    } catch (_) {
      return units.first;
    }
  }

  // Get display stock in multiple units (Box, Strip, Tablet)
  String get stockDisplay {
    if (type == ProductType.service || units.isEmpty) return '∞';
    
    // For now, let's just show the individual physical stocks
    List<String> parts = [];
    for (var u in units) {
      if (u.stock > 0) {
        parts.add('${u.stock.toStringAsFixed(0)} ${u.unitName}');
      }
    }
    
    if (parts.isEmpty) return '0 $unit';
    return parts.join(', ');
  }

  bool get isService => type == ProductType.service;
  bool get isGoods => type == ProductType.goods;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'cost': cost,
      'stock': stock,
      'unit': unit,
      'type': type.value,
      'duration_days': durationDays,
      'expire_days': expireDays,
      'image_url': imageUrl,
      'barcode': barcode,
      'is_active': isActive ? 1 : 0,
      'server_id': serverId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, {List<ProductUnit> units = const []}) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: map['price'] as int,
      cost: (map['cost'] as int?) ?? 0,
      stock: (map['stock'] as num?)?.toDouble(),
      unit: map['unit'] as String,
      type: ProductTypeExtension.fromString(map['type'] as String),
      durationDays: map['duration_days'] as int?,
      expireDays: (map['expire_days'] as int?) ?? 0,
      imageUrl: map['image_url'] as String?,
      barcode: map['barcode'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      serverId: map['server_id'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      units: units,
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? description,
    int? price,
    int? cost,
    double? stock,
    String? unit,
    ProductType? type,
    int? durationDays,
    String? imageUrl,
    String? barcode,
    int? expireDays,
    bool? isActive,
    int? serverId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProductUnit>? units,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      type: type ?? this.type,
      durationDays: durationDays ?? this.durationDays,
      expireDays: expireDays ?? this.expireDays,
      imageUrl: imageUrl ?? this.imageUrl,
      barcode: barcode ?? this.barcode,
      isActive: isActive ?? this.isActive,
      serverId: serverId ?? this.serverId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      units: units ?? this.units,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        price,
        cost,
        stock,
        unit,
        type,
        durationDays,
        expireDays,
        imageUrl,
        barcode,
        isActive,
        serverId,
        createdAt,
        updatedAt,
        units,
      ];
}
