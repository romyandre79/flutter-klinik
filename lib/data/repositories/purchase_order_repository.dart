import 'package:kreatif_klinik/data/database/database_helper.dart';
import 'package:kreatif_klinik/data/models/purchase_order.dart';
import 'package:kreatif_klinik/data/models/purchase_order_item.dart';
import 'package:kreatif_klinik/data/models/supplier.dart';
import 'package:kreatif_klinik/data/repositories/product_repository.dart';
import 'package:kreatif_klinik/data/models/purchase_order_item_batch.dart';

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

    List<PurchaseOrderItem> items = [];
    for (final itemMap in itemsResult) {
      final poItem = PurchaseOrderItem.fromMap(itemMap);
      
      // Get Batches for this item
      final batchesResult = await db.query(
        'purchase_order_item_batches',
        where: 'purchase_order_item_id = ?',
        whereArgs: [poItem.id],
      );
      
      final itemBatches = batchesResult
          .map((map) => PurchaseOrderItemBatch.fromMap(map))
          .toList();
          
      items.add(poItem.copyWith(batches: itemBatches));
    }

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

  // Receive PO with multi-batch details
  Future<void> receivePurchaseOrder(
    int id, 
    List<PurchaseOrderItemBatch> batches, {
    String? noFaktur,
    String? tglFaktur,
    String? keterangan,
  }) async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      // 1. Update PO status to received
      await txn.update(
        'purchase_orders',
        {
          'status': 'received',
          'no_faktur': noFaktur,
          'tgl_faktur': tglFaktur,
          'keterangan': keterangan,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // 2. Insert batches and update product stocks
      for (final batch in batches) {
        // Insert batch details
        await txn.insert('purchase_order_item_batches', {
          'purchase_order_item_id': batch.purchaseOrderItemId,
          'product_id': batch.productId,
          'batch_no': batch.batchNo,
          'expired_date': batch.expiredDate.toIso8601String(),
          'quantity': batch.quantity,
        });

        // Get the unit from purchase_order_item to update the correct product unit stock
        final poItems = await txn.query(
          'purchase_order_items',
          columns: ['unit'],
          where: 'id = ?',
          whereArgs: [batch.purchaseOrderItemId],
        );

        final unitName = poItems.isNotEmpty ? (poItems.first['unit'] as String? ?? 'pcs') : 'pcs';

        // Update product stock by unit name
        await _productRepository.updateStockByUnitName(
          txn,
          batch.productId,
          unitName,
          batch.quantity,
        );
      }
    });
  }

  // Delete PO
  // If PO is received, revert the stock updates before deleting it
  Future<void> deletePurchaseOrder(int id) async {
    final db = await _databaseHelper.database;
    
    await db.transaction((txn) async {
      // Get the PO to check its status
      final poResult = await txn.query(
        'purchase_orders',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [id],
      );

      if (poResult.isNotEmpty) {
        final status = poResult.first['status'] as String;

        if (status == 'received') {
          // Find batches for the items in this PO
          final batches = await txn.rawQuery('''
            SELECT b.*, i.unit 
            FROM purchase_order_item_batches b
            JOIN purchase_order_items i ON b.purchase_order_item_id = i.id
            WHERE i.purchase_order_id = ?
          ''', [id]);

          if (batches.isNotEmpty) {
            for (final batch in batches) {
              final productId = batch['product_id'] as int;
              final quantity = (batch['quantity'] as num).toDouble();
              final unitName = batch['unit'] as String? ?? 'pcs';

              // Deduct stock (negative quantity)
              await _productRepository.updateStockByUnitName(
                txn,
                productId,
                unitName,
                -quantity,
              );
            }
          } else {
            // Fallback: If no batches found (e.g. old PO received before migration), revert using PO items
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
                  -quantity.toDouble(),
                );
              }
            }
          }
        }
      }

      // Delete PO (cascade delete will handle items and batches in DB)
      await txn.delete(
        'purchase_orders',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
