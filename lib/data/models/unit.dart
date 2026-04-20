import 'package:equatable/equatable.dart';

class Unit extends Equatable {
  final int? id;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? serverId;

  const Unit({
    this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
    this.serverId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'server_id': serverId,
    };
  }

  factory Unit.fromMap(Map<String, dynamic> map) {
    return Unit(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      serverId: map['server_id'] as int?,
    );
  }

  Unit copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? serverId,
  }) {
    return Unit(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverId: serverId ?? this.serverId,
    );
  }

  @override
  List<Object?> get props => [id, name, createdAt, updatedAt, serverId];
}
