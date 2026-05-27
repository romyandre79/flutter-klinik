import 'package:kreatif_klinik/data/database/database_helper.dart';
import 'package:kreatif_klinik/data/models/examination.dart';

class ExaminationRepository {
  final DatabaseHelper _databaseHelper;

  ExaminationRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<Examination?> getExaminationByRegistrationId(int registrationId) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'examinations',
      where: 'registration_id = ?',
      whereArgs: [registrationId],
    );
    if (result.isEmpty) return null;
    return Examination.fromMap(result.first);
  }

  Future<Examination> saveExamination(Examination examination) async {
    final db = await _databaseHelper.database;
    final existing = await getExaminationByRegistrationId(examination.registrationId);
    final now = DateTime.now().toIso8601String();

    if (existing != null) {
      await db.update(
        'examinations',
        {
          ...examination.toMap(),
          'updated_at': now,
        },
        where: 'registration_id = ?',
        whereArgs: [examination.registrationId],
      );
      return examination.copyWith(id: existing.id, updatedAt: DateTime.parse(now));
    } else {
      final id = await db.insert('examinations', {
        ...examination.toMap(),
        'created_at': now,
        'updated_at': now,
      }..remove('id'));
      return examination.copyWith(id: id, createdAt: DateTime.parse(now), updatedAt: DateTime.parse(now));
    }
  }
}
