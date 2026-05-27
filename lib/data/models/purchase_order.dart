import 'package:kreatif_otopart/data/models/purchase_order_item.dart';
import 'package:kreatif_otopart/data/models/supplier.dart';

class PurchaseOrder {
  final int? id;
  final int supplierId;
  final DateTime orderDate;
  final DateTime? expectedDate;
  final String status; // 'pending', 'received', 'cancelled'
  final int totalAmount;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int isSynced;
  final int? serverId;
  
  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Belum Dikirim';
      case 'received':
        return 'Sudah Terima';
      case 'cancelled':
        return 'Batal';
      default:
        return status.toUpperCase();
    }
  }
  
  // Relations
  final Supplier? supplier;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    this.id,
    required this.supplierId,
    required this.orderDate,
    this.expectedDate,
    required this.status,
    required this.totalAmount,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.isSynced = 0,
    this.serverId,
    this.supplier,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'order_date': orderDate.toIso8601String(),
      'expected_date': expectedDate?.toIso8601String(),
      'status': status,
      'total_amount': totalAmount,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_synced': isSynced,
      'server_id': serverId,
    };
  }

  factory PurchaseOrder.fromMap(Map<String, dynamic> map, {Supplier? supplier, List<PurchaseOrderItem>? items}) {
    return PurchaseOrder(
      id: map['id'] as int?,
      supplierId: map['supplier_id'] as int,
      orderDate: DateTime.parse(map['order_date']),
      expectedDate: map['expected_date'] != null ? DateTime.parse(map['expected_date']) : null,
      status: map['status'] as String,
      totalAmount: map['total_amount'] as int,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      isSynced: (map['is_synced'] as int?) ?? 0,
      serverId: map['server_id'] as int?,
      supplier: supplier,
      items: items ?? [],
    );
  }

  PurchaseOrder copyWith({
    int? id,
    int? supplierId,
    DateTime? orderDate,
    DateTime? expectedDate,
    String? status,
    int? totalAmount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? isSynced,
    int? serverId,
    Supplier? supplier,
    List<PurchaseOrderItem>? items,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      orderDate: orderDate ?? this.orderDate,
      expectedDate: expectedDate ?? this.expectedDate,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      serverId: serverId ?? this.serverId,
      supplier: supplier ?? this.supplier,
      items: items ?? this.items,
    );
  }
}
