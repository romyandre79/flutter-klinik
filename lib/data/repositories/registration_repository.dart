import 'package:kreatif_klinik/data/database/database_helper.dart';
import 'package:kreatif_klinik/data/models/registration.dart';

class RegistrationRepository {
  final DatabaseHelper _databaseHelper;

  RegistrationRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<List<Registration>> getAllRegistrations() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT r.*, c.name AS customer_name, c.phone AS customer_phone, d.name AS doctor_name
      FROM registrations r
      INNER JOIN customers c ON r.customer_id = c.id
      INNER JOIN doctors d ON r.doctor_id = d.id
      ORDER BY r.registration_date DESC, r.id DESC
    ''');
    return result.map((map) => Registration.fromMap(map)).toList();
  }

  Future<Registration> createRegistration(Registration registration) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('registrations', {
      ...registration.toMap(),
      'created_at': now,
      'updated_at': now,
    }..remove('id'));

    // Fetch newly created registration with joins
    final result = await db.rawQuery('''
      SELECT r.*, c.name AS customer_name, c.phone AS customer_phone, d.name AS doctor_name
      FROM registrations r
      INNER JOIN customers c ON r.customer_id = c.id
      INNER JOIN doctors d ON r.doctor_id = d.id
      WHERE r.id = ?
    ''', [id]);
    
    if (result.isNotEmpty) {
      return Registration.fromMap(result.first);
    }
    return registration.copyWith(id: id);
  }

  Future<int> updateRegistrationStatus(int id, String status) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'registrations',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteRegistration(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'registrations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> generateNextRegistrationNo() async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();
    final dateStr = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'; // yyMMdd
    
    final result = await db.rawQuery('''
      SELECT MAX(CAST(SUBSTR(registration_no, 12) AS INTEGER)) as max_num
      FROM registrations
      WHERE registration_no LIKE ?
    ''', ['REG-$dateStr-%']);

    int nextNum = 1;
    if (result.isNotEmpty && result.first['max_num'] != null) {
      nextNum = (result.first['max_num'] as int) + 1;
    }

    final paddedNum = nextNum.toString().padLeft(4, '0');
    return 'REG-$dateStr-$paddedNum';
  }
}
