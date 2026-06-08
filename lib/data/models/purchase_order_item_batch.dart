class PurchaseOrderItemBatch {
  final int? id;
  final int purchaseOrderItemId;
  final int productId;
  final String batchNo;
  final DateTime expiredDate;
  final double quantity;

  PurchaseOrderItemBatch({
    this.id,
    required this.purchaseOrderItemId,
    required this.productId,
    required this.batchNo,
    required this.expiredDate,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_order_item_id': purchaseOrderItemId,
      'product_id': productId,
      'batch_no': batchNo,
      'expired_date': expiredDate.toIso8601String(),
      'quantity': quantity,
    };
  }

  factory PurchaseOrderItemBatch.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItemBatch(
      id: map['id'] as int?,
      purchaseOrderItemId: map['purchase_order_item_id'] as int,
      productId: map['product_id'] as int,
      batchNo: map['batch_no'] as String,
      expiredDate: DateTime.parse(map['expired_date'] as String),
      quantity: (map['quantity'] as num).toDouble(),
    );
  }

  PurchaseOrderItemBatch copyWith({
    int? id,
    int? purchaseOrderItemId,
    int? productId,
    String? batchNo,
    DateTime? expiredDate,
    double? quantity,
  }) {
    return PurchaseOrderItemBatch(
      id: id ?? this.id,
      purchaseOrderItemId: purchaseOrderItemId ?? this.purchaseOrderItemId,
      productId: productId ?? this.productId,
      batchNo: batchNo ?? this.batchNo,
      expiredDate: expiredDate ?? this.expiredDate,
      quantity: quantity ?? this.quantity,
    );
  }
}
