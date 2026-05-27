import 'package:kreatif_pos/data/database/database_helper.dart';
import 'package:kreatif_pos/data/models/pengumuman_template.dart';

class PengumumanTemplateRepository {
  final DatabaseHelper _databaseHelper;

  PengumumanTemplateRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<List<PengumumanTemplate>> getTemplates({String? type}) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pengumuman_templates',
      where: type != null ? 'type = ?' : null,
      whereArgs: type != null ? [type] : null,
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => PengumumanTemplate.fromMap(maps[i]));
  }

  Future<int> addTemplate(PengumumanTemplate template) async {
    final db = await _databaseHelper.database;
    return await db.insert('pengumuman_templates', template.toMap());
  }

  Future<int> updateTemplate(PengumumanTemplate template) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'pengumuman_templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  Future<int> deleteTemplate(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'pengumuman_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
