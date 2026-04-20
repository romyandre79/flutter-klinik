class Supplier {
  final int? id;
  final String name;
  final String? contactPerson;
  final String? address;
  final String? phone;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? serverId;

  Supplier({
    this.id,
    required this.name,
    this.contactPerson,
    this.address,
    this.phone,
    this.email,
    this.createdAt,
    this.updatedAt,
    this.serverId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact_person': contactPerson,
      'address': address,
      'phone': phone,
      'email': email,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'server_id': serverId,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] as String,
      contactPerson: map['contact_person'] as String?,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      serverId: map['server_id'] as int?,
    );
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? contactPerson,
    String? address,
    String? phone,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? serverId,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverId: serverId ?? this.serverId,
    );
  }
}
