class Examination {
  final int? id;
  final int registrationId;
  final String? symptoms;
  final String? diagnosis;
  final String? therapy;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Examination({
    this.id,
    required this.registrationId,
    this.symptoms,
    this.diagnosis,
    this.therapy,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'registration_id': registrationId,
      'symptoms': symptoms,
      'diagnosis': diagnosis,
      'therapy': therapy,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Examination.fromMap(Map<String, dynamic> map) {
    return Examination(
      id: map['id'] as int?,
      registrationId: map['registration_id'] as int,
      symptoms: map['symptoms'] as String?,
      diagnosis: map['diagnosis'] as String?,
      therapy: map['therapy'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Examination copyWith({
    int? id,
    int? registrationId,
    String? symptoms,
    String? diagnosis,
    String? therapy,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Examination(
      id: id ?? this.id,
      registrationId: registrationId ?? this.registrationId,
      symptoms: symptoms ?? this.symptoms,
      diagnosis: diagnosis ?? this.diagnosis,
      therapy: therapy ?? this.therapy,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
