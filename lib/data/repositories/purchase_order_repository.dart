import 'package:kreatif_klinik/data/database/database_helper.dart';
import 'package:kreatif_klinik/data/models/purchase_order.dart';
import 'package:kreatif_klinik/data/models/purchase_order_item.dart';
import 'package:kreatif_klinik/data/models/supplier.dart';
import 'package:kreatif_klinik/data/repositories/product_repository.dart';

class PurchaseOrderRepository {
  final DatabaseHelper _databaseHelper;
  final ProductRepository _productRepository;

  PurchaseOrderRepository({DatabaseHelper? databaseHelper, ProductRepository? productRepository})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _productRepository = productRepository ?? ProductRepository();

  // Get all POs with basic info
  Future<List<PurchaseOrder>> getAllPurchaseOrders() async {
    final db = await _databaseHelper.database;
    
    // Join with suppliers to get supplier name
    final result = await db.rawQuery('''
      SELECT po.*, s.name as supplier_name 
      FROM purchase_orders po
      LEFT JOIN suppliers s ON po.supplier_id = s.id
      ORDER BY po.order_date DESC
    ''');

    return result.map((map) {
      // Create a partial supplier object for display
      final supplier = map['supplier_name'] != null 
          ? Supplier(id: map['supplier_id'] as int, name: map['supplier_name'] as String) 
          : null;
          
      return PurchaseOrder.fromMap(map, supplier: supplier);
    }).toList();
  }

  // Get single PO with items
  Future<PurchaseOrder?> getPurchaseOrderById(int id) async {
    final db = await _databaseHelper.database;
    
    // Get PO
    final poResult = await db.rawQuery('''
      SELECT po.*, s.name as supplier_name, s.phone as supplier_phone, s.address as supplier_address, s.email as supplier_email, s.contact_person as supplier_contact
      FROM purchase_orders po
      LEFT JOIN suppliers s ON po.supplier_id = s.id
      WHERE po.id = ?
    ''', [id]);

    if (poResult.isEmpty) return null;

    final poMap = poResult.first;
    
    // Get Items
    final itemsResult = await db.query(
      'purchase_order_items',
      where: 'purchase_order_id = ?',
      whereArgs: [id],
    );

    final items = itemsResult.map((map) => PurchaseOrderItem.fromMap(map)).toList();

    // Construct Supplier
    final supplier = poMap['supplier_name'] != null 
        ? Supplier(
            id: poMap['supplier_id'] as int, 
            name: poMap['supplier_name'] as String,
            phone: poMap['supplier_phone'] as String?,
            address: poMap['supplier_address'] as String?,
            email: poMap['supplier_email'] as String?,
            contactPerson: poMap['supplier_contact'] as String?,
          ) 
        : null;

    return PurchaseOrder.fromMap(poMap, supplier: supplier, items: items);
  }

  // Create PO with items
  Future<PurchaseOrder> createPurchaseOrder(PurchaseOrder po) async {
    final db = await _databaseHelper.database;
    
    return await db.transaction((txn) async {
      // Insert PO
        final poId = await txn.insert('purchase_orders', {
        ...po.toMap(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }..remove('id')); // Let DB generate ID

      // Insert Items
      List<PurchaseOrderItem> newItems = [];
      for (final item in po.items) {
        final itemId = await txn.insert('purchase_order_items', {
          ...item.toMap(),
          'purchase_order_id': poId,
          'created_at': DateTime.now().toIso8601String(),
        }..remove('id'));
        newItems.add(item.copyWith(id: itemId, purchaseOrderId: poId));
      }

      return po.copyWith(id: poId, items: newItems);
    });
  }

  // Update PO Status (e.g., to 'received')
  // When status is 'received', also update product stock
  Future<void> updatePurchaseOrderStatus(int id, String status) async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      // Update PO status
      await txn.update(
        'purchase_orders',
        {
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // If received, update product stock
      if (status == 'received') {
        final items = await txn.query(
          'purchase_order_items',
          where: 'purchase_order_id = ?',
          whereArgs: [id],
        );

        for (final item in items) {
          final productId = item['product_id'] as int?;
          final quantity = item['quantity'] as int;

          if (productId != null) {
            final unitName = item['unit'] as String? ?? 'pcs';
            await _productRepository.updateStockByUnitName(
              txn, 
              productId, 
              unitName, 
              quantity.toDouble(),
            );
          }
        }
      }
    });
  }

  // Delete PO (Cascade delete items handled by DB schema if configured, but safe to do manual or rely on FK)
  // FK is ON DELETE CASCADE in schema, so items will be deleted automatically.
  Future<void> deletePurchaseOrder(int id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'purchase_orders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
