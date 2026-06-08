class OrderItemBatch {
  final int? id;
  final int? orderItemId;
  final int productId;
  final String batchNo;
  final DateTime expiredDate;
  final double quantity;

  OrderItemBatch({
    this.id,
    this.orderItemId,
    required this.productId,
    required this.batchNo,
    required this.expiredDate,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_item_id': orderItemId,
      'product_id': productId,
      'batch_no': batchNo,
      'expired_date': expiredDate.toIso8601String(),
      'quantity': quantity,
    };
  }

  factory OrderItemBatch.fromMap(Map<String, dynamic> map) {
    return OrderItemBatch(
      id: map['id'] as int?,
      orderItemId: map['order_item_id'] as int?,
      productId: map['product_id'] as int,
      batchNo: map['batch_no'] as String,
      expiredDate: DateTime.parse(map['expired_date'] as String),
      quantity: (map['quantity'] as num).toDouble(),
    );
  }

  OrderItemBatch copyWith({
    int? id,
    int? orderItemId,
    int? productId,
    String? batchNo,
    DateTime? expiredDate,
    double? quantity,
  }) {
    return OrderItemBatch(
      id: id ?? this.id,
      orderItemId: orderItemId ?? this.orderItemId,
      productId: productId ?? this.productId,
      batchNo: batchNo ?? this.batchNo,
      expiredDate: expiredDate ?? this.expiredDate,
      quantity: quantity ?? this.quantity,
    );
  }
}
