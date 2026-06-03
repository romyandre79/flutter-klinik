import 'package:kreatif_pos/data/database/database_helper.dart';
import 'package:kreatif_pos/data/models/unit.dart';

class UnitRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Unit>> getUnits() async {
    final db = await _dbHelper.database;
    final result = await db.query('units', orderBy: 'name ASC');
    return result.map((e) => Unit.fromMap(e)).toList();
  }

  Future<int> addUnit(Unit unit) async {
    final db = await _dbHelper.database;
    return await db.insert('units', {
      'name': unit.name,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateUnit(Unit unit) async {
    final db = await _dbHelper.database;
    return await db.update(
      'units',
      {
        'name': unit.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [unit.id],
    );
  }

  Future<int> deleteUnit(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'units',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
