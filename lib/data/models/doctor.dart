class Doctor {
  final int? id;
  final String name;
  final String? specialization;
  final String? phone;
  final int isActive;
  final int? serverId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Doctor({
    this.id,
    required this.name,
    this.specialization,
    this.phone,
    this.isActive = 1,
    this.serverId,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'specialization': specialization,
      'phone': phone,
      'is_active': isActive,
      'server_id': serverId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Doctor.fromMap(Map<String, dynamic> map) {
    return Doctor(
      id: map['id'] as int?,
      name: map['name'] as String,
      specialization: map['specialization'] as String?,
      phone: map['phone'] as String?,
      isActive: (map['is_active'] as int?) ?? 1,
      serverId: map['server_id'] as int?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Doctor copyWith({
    int? id,
    String? name,
    String? specialization,
    String? phone,
    int? isActive,
    int? serverId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      specialization: specialization ?? this.specialization,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      serverId: serverId ?? this.serverId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
