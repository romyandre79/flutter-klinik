import 'package:kreatif_otopart/data/database/database_helper.dart';
import 'package:kreatif_otopart/data/models/stock_transfer.dart';
import 'package:sqflite/sqflite.dart';

class StockTransferRepository {
  final DatabaseHelper _databaseHelper;

  StockTransferRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<List<StockTransfer>> getStockTransfers() async {
    final db = await _databaseHelper.database;
    
    // Join with products to get names
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT st.*, 
             p1.name as source_product_name, 
             p2.name as target_product_name
      FROM stock_transfers st
      LEFT JOIN products p1 ON st.source_product_id = p1.id
      LEFT JOIN products p2 ON st.target_product_id = p2.id
      ORDER BY st.created_at DESC
    ''');

    return List.generate(maps.length, (i) => StockTransfer.fromMap(maps[i]));
  }

  Future<void> createTransfer(StockTransfer transfer) async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      // 1. Insert transfer record
      await txn.insert('stock_transfers', transfer.toMap());

      // 2. Decrease source stock
      await txn.rawUpdate('''
        UPDATE products 
        SET stock = stock - ?, 
            updated_at = ? 
        WHERE id = ?
      ''', [
        transfer.sourceQty, 
        DateTime.now().toIso8601String(), 
        transfer.sourceProductId
      ]);

      // 3. Increase target stock
      await txn.rawUpdate('''
        UPDATE products 
        SET stock = stock + ?, 
            updated_at = ? 
        WHERE id = ?
      ''', [
        transfer.targetQty, 
        DateTime.now().toIso8601String(), 
        transfer.targetProductId
      ]);
    });
  }
}
