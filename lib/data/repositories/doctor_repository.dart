import 'package:kreatif_klinik/data/database/database_helper.dart';
import 'package:kreatif_klinik/data/models/doctor.dart';

class DoctorRepository {
  final DatabaseHelper _databaseHelper;

  DoctorRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<List<Doctor>> getAllDoctors() async {
    final db = await _databaseHelper.database;
    final result = await db.query('doctors', where: 'is_active = 1', orderBy: 'name ASC');
    return result.map((map) => Doctor.fromMap(map)).toList();
  }

  Future<Doctor> createDoctor(Doctor doctor) async {
    final db = await _databaseHelper.database;
    final id = await db.insert('doctors', {
      ...doctor.toMap(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }..remove('id'));
    return doctor.copyWith(id: id);
  }

  Future<int> updateDoctor(Doctor doctor) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'doctors',
      {
        ...doctor.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [doctor.id],
    );
  }

  Future<int> deleteDoctor(int id) async {
    final db = await _databaseHelper.database;
    // Perform soft delete by setting is_active = 0
    return await db.update(
      'doctors',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
