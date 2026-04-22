import 'package:sqflite/sqflite.dart';
import 'package:kreatif_klinik/data/database/database_helper.dart';

import 'package:kreatif_klinik/data/models/product.dart';
import 'package:kreatif_klinik/data/models/product_unit.dart';

class ProductRepository {
  final DatabaseHelper _databaseHelper;

  ProductRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<List<Product>> getProducts({ProductType? type, bool activeOnly = true, String? query}) async {
    final db = await _databaseHelper.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (activeOnly) {
      whereClause = 'is_active = 1';
    }

    if (type != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND type = ?';
      } else {
        whereClause = 'type = ?';
      }
      whereArgs.add(type.value);
    }

    if (query != null && query.isNotEmpty) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND (name LIKE ? OR barcode LIKE ?)';
      } else {
        whereClause = '(name LIKE ? OR barcode LIKE ?)';
      }
      final queryParam = '%$query%';
      whereArgs.add(queryParam);
      whereArgs.add(queryParam);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    List<Product> products = [];
    for (var map in maps) {
      final List<Map<String, dynamic>> unitMaps = await db.query(
        'product_units',
        where: 'product_id = ?',
        whereArgs: [map['id']],
      );
      final units = unitMaps.map((u) => ProductUnit.fromMap(u)).toList();
      products.add(Product.fromMap(map, units: units));
    }
    return products;
  }

  Future<Product?> getProductById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final List<Map<String, dynamic>> unitMaps = await db.query(
        'product_units',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      final units = unitMaps.map((u) => ProductUnit.fromMap(u)).toList();
      return Product.fromMap(maps.first, units: units);
    }
    return null;
  }

  Future<int> addProduct(Product product) async {
    final db = await _databaseHelper.database;
    return await db.transaction((txn) async {
      final id = await txn.insert('products', product.toMap());
      
      int? baseUnitId;
      // First pass: Insert base unit (no parent)
      for (var unit in product.units) {
        if (unit.parentUnitId == null) {
          baseUnitId = await txn.insert('product_units', unit.copyWith(productId: id).toMap());
          break; 
        }
      }

      // If no unit has parentUnitId == null, use first as base for safety
      if (baseUnitId == null && product.units.isNotEmpty) {
        baseUnitId = await txn.insert('product_units', product.units.first.copyWith(productId: id).toMap());
      }

      // Second pass: Insert other units with parentUnitId = baseUnitId
      for (var unit in product.units) {
        // Skip the one we already inserted if we can identify it, 
        // but for safety we just skip the one with null parent if we used it as base.
        if (unit.parentUnitId != null || (baseUnitId != null && unit.unitName != product.unit)) {
          await txn.insert('product_units', unit.copyWith(
            productId: id,
            parentUnitId: baseUnitId,
          ).toMap());
        }
      }
      return id;
    });
  }

  Future<int> updateProduct(Product product) async {
    final db = await _databaseHelper.database;
    return await db.transaction((txn) async {
      final rows = await txn.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );

      // Get existing units to decide what to update/insert/delete
      final List<Map<String, dynamic>> existingUnitMaps = await txn.query(
        'product_units',
        where: 'product_id = ?',
        whereArgs: [product.id],
      );
      
      final existingIds = existingUnitMaps.map((m) => m['id'] as int).toSet();
      final newIds = product.units.where((u) => u.id != null).map((u) => u.id!).toSet();

      // Delete units that are no longer present
      for (final id in existingIds) {
        if (!newIds.contains(id)) {
          await txn.delete('product_units', where: 'id = ?', whereArgs: [id]);
        }
      }

      // Identify base unit (parentUnitId == null)
      int? baseUnitId;
      for (var unit in product.units) {
        if (unit.unitName == product.unit) {
          if (unit.id != null && existingIds.contains(unit.id)) {
            await txn.update('product_units', unit.toMap(), where: 'id = ?', whereArgs: [unit.id]);
            baseUnitId = unit.id;
          } else {
            baseUnitId = await txn.insert('product_units', unit.copyWith(productId: product.id).toMap());
          }
          break;
        }
      }

      // Update or Insert other units
      for (var unit in product.units) {
        if (unit.unitName == product.unit) continue; // Already handled

        if (unit.id != null && existingIds.contains(unit.id)) {
          await txn.update(
            'product_units',
            unit.copyWith(parentUnitId: baseUnitId).toMap(),
            where: 'id = ?',
            whereArgs: [unit.id],
          );
        } else {
          await txn.insert('product_units', unit.copyWith(
            productId: product.id,
            parentUnitId: baseUnitId,
          ).toMap());
        }
      }
      return rows;
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await _databaseHelper.database;
    // Soft delete: set is_active to 0
    return await db.update(
      'products',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> hardDeleteProduct(int id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  Future<void> updateStock(int productId, double quantityChange, {int? unitId}) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      if (unitId == null) {
        // Fallback to legacy behavior if unitId not provided
        await txn.rawUpdate(
          'UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?',
          [quantityChange, DateTime.now().toIso8601String(), productId],
        );
      } else {
        await _deductStockRecursive(txn, productId, unitId, -quantityChange);
      }
    });
  }

  // Public wrapper for unit-aware stock updates using unit Name (case-insensitive)
  Future<void> updateStockByUnitName(Transaction txn, int productId, String unitName, double quantityChange) async {
    // Find the unit ID for this product and unit name (case-insensitive)
    final List<Map<String, dynamic>> unitResults = await txn.query(
      'product_units',
      where: 'product_id = ? AND LOWER(unit_name) = LOWER(?)',
      whereArgs: [productId, unitName.trim()],
    );

    if (unitResults.isNotEmpty) {
      final unit = ProductUnit.fromMap(unitResults.first);
      // Update specific unit stock
      final currentStock = unit.stock;
      await txn.update(
        'product_units', 
        {'stock': currentStock + quantityChange}, 
        where: 'id = ?', 
        whereArgs: [unit.id]
      );
      
      // Sync products.stock (Total in Base Unit)
      // Assumption: 1 additional unit = multiplier * base unit
      final deltaBase = quantityChange * unit.multiplier;
      await txn.rawUpdate(
        'UPDATE products SET stock = COALESCE(stock, 0) + ?, updated_at = ? WHERE id = ?',
        [deltaBase, DateTime.now().toIso8601String(), productId],
      );
    } else {
      // Fallback: update products table if no specific unit record found
      await txn.rawUpdate(
        'UPDATE products SET stock = COALESCE(stock, 0) + ?, updated_at = ? WHERE id = ?',
        [quantityChange, DateTime.now().toIso8601String(), productId],
      );
    }
  }

  // Recursive deduction with automatic conversion
  Future<void> _deductStockRecursive(Transaction txn, int productId, int unitId, double amountToDeduct) async {
    final List<Map<String, dynamic>> units = await txn.query('product_units', where: 'id = ?', whereArgs: [unitId]);
    if (units.isEmpty) return;
    
    final unit = ProductUnit.fromMap(units.first);
    double currentStock = unit.stock;

    if (currentStock >= amountToDeduct) {
      await txn.update('product_units', {'stock': currentStock - amountToDeduct}, where: 'id = ?', whereArgs: [unitId]);
    } else {
      // Need more stock. Check if parent exists
      if (unit.parentUnitId != null) {
        // Calculate how many parent units we need to break
        double neededFromParent = ((amountToDeduct - currentStock) / unit.multiplier).ceilToDouble();
        
        // Break X units of parent
        await _deductStockRecursive(txn, productId, unit.parentUnitId!, neededFromParent);
        
        // Logging the auto-conversion
        await txn.insert('unit_conversions', {
          'product_id': productId,
          'from_unit_id': unit.parentUnitId,
          'to_unit_id': unitId,
          'qty_changed': neededFromParent * unit.multiplier,
          'type': 'auto',
        });

        // Current stock increased
        final updatedUnits = await txn.query('product_units', where: 'id = ?', whereArgs: [unitId]);
        final updatedStock = (updatedUnits.first['stock'] as num).toDouble() + (neededFromParent * unit.multiplier);
        
        // Now deduct
        await txn.update('product_units', {'stock': updatedStock - amountToDeduct}, where: 'id = ?', whereArgs: [unitId]);
      } else {
        // No parent, but still need stock?
        await txn.update('product_units', {'stock': currentStock - amountToDeduct}, where: 'id = ?', whereArgs: [unitId]);
      }
    }
  }

  Future<void> convertUnit({
    required int productId,
    required int fromUnitId,
    required int toUnitId,
    required double fromQty,
    required double multiplier,
  }) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      // Deduct from source
      await txn.rawUpdate('UPDATE product_units SET stock = stock - ? WHERE id = ?', [fromQty, fromUnitId]);
      // Add to target
      await txn.rawUpdate('UPDATE product_units SET stock = stock + ? WHERE id = ?', [fromQty * multiplier, toUnitId]);
      
      // Log conversion
      await txn.insert('unit_conversions', {
        'product_id': productId,
        'from_unit_id': fromUnitId,
        'to_unit_id': toUnitId,
        'qty_changed': fromQty * multiplier,
        'type': 'manual',
      });
    });
  }

  Future<void> addProducts(List<Product> products) async {
    final db = await _databaseHelper.database;
    final batch = db.batch();

    for (var product in products) {
      batch.insert('products', product.toMap());
    }

    await batch.commit(noResult: true);
  }
}
