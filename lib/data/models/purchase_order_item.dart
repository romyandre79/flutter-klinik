import 'package:kreatif_klinik/data/models/purchase_order_item_batch.dart';

class PurchaseOrderItem {
  final int? id;
  final int? purchaseOrderId; // Nullable during creation
  final String itemName;
  final int quantity;
  final String unit;
  final int cost; // Price per unit
  final int subtotal;
  final int? productId; // Link to master product
  final DateTime? createdAt;
  final List<PurchaseOrderItemBatch> batches; // Received batches

  PurchaseOrderItem({
    this.id,
    this.purchaseOrderId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.cost,
    required this.subtotal,
    this.productId,
    this.createdAt,
    this.batches = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_order_id': purchaseOrderId,
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
      'cost': cost,
      'subtotal': subtotal,
      'product_id': productId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map, {List<PurchaseOrderItemBatch> batches = const []}) {
    return PurchaseOrderItem(
      id: map['id'] as int?,
      purchaseOrderId: map['purchase_order_id'] as int?,
      itemName: map['item_name'] as String,
      quantity: map['quantity'] as int,
      unit: map['unit'] as String? ?? 'pcs',
      cost: map['cost'] as int,
      subtotal: map['subtotal'] as int,
      productId: map['product_id'] as int?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      batches: batches,
    );
  }

  PurchaseOrderItem copyWith({
    int? id,
    int? purchaseOrderId,
    String? itemName,
    int? quantity,
    String? unit,
    int? cost,
    int? subtotal,
    int? productId,
    DateTime? createdAt,
    List<PurchaseOrderItemBatch>? batches,
  }) {
    return PurchaseOrderItem(
      id: id ?? this.id,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      cost: cost ?? this.cost,
      subtotal: subtotal ?? this.subtotal,
      productId: productId ?? this.productId,
      createdAt: createdAt ?? this.createdAt,
      batches: batches ?? this.batches,
    );
  }
}
