import 'package:kreatif_pos/data/database/database_helper.dart';
import 'package:kreatif_pos/data/models/supplier.dart';

class SupplierRepository {
  final DatabaseHelper _databaseHelper;

  SupplierRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<List<Supplier>> getAllSuppliers() async {
    final db = await _databaseHelper.database;
    final result = await db.query('suppliers', orderBy: 'name ASC');
    return result.map((map) => Supplier.fromMap(map)).toList();
  }

  Future<Supplier> createSupplier(Supplier supplier) async {
    final db = await _databaseHelper.database;
    final id = await db.insert('suppliers', {
      ...supplier.toMap(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }..remove('id')); // Let DB generate ID

    return supplier.copyWith(id: id);
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'suppliers',
      {
        ...supplier.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<int> deleteSupplier(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addSuppliers(List<Supplier> suppliers) async {
    final db = await _databaseHelper.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (var supplier in suppliers) {
      batch.insert('suppliers', {
        'name': supplier.name,
        'contact_person': supplier.contactPerson,
        'address': supplier.address,
        'phone': supplier.phone,
        'email': supplier.email,
        'created_at': now,
        'updated_at': now,
      });
    }

    await batch.commit(noResult: true);
  }
}
