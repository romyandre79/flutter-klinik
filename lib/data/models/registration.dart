class Registration {
  final int? id;
  final String registrationNo;
  final int customerId;
  final int doctorId;
  final DateTime registrationDate;
  final String? complaint;
  final String status; // 'pending', 'examining', 'completed', 'cancelled'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined properties (non-database columns)
  final String? customerName;
  final String? customerPhone;
  final String? doctorName;

  Registration({
    this.id,
    required this.registrationNo,
    required this.customerId,
    required this.doctorId,
    required this.registrationDate,
    this.complaint,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
    this.customerName,
    this.customerPhone,
    this.doctorName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'registration_no': registrationNo,
      'customer_id': customerId,
      'doctor_id': doctorId,
      'registration_date': registrationDate.toIso8601String(),
      'complaint': complaint,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Registration.fromMap(Map<String, dynamic> map) {
    return Registration(
      id: map['id'] as int?,
      registrationNo: map['registration_no'] as String,
      customerId: map['customer_id'] as int,
      doctorId: map['doctor_id'] as int,
      registrationDate: DateTime.parse(map['registration_date'] as String),
      complaint: map['complaint'] as String?,
      status: map['status'] as String? ?? 'pending',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      doctorName: map['doctor_name'] as String?,
    );
  }

  Registration copyWith({
    int? id,
    String? registrationNo,
    int? customerId,
    int? doctorId,
    DateTime? registrationDate,
    String? complaint,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
    String? customerPhone,
    String? doctorName,
  }) {
    return Registration(
      id: id ?? this.id,
      registrationNo: registrationNo ?? this.registrationNo,
      customerId: customerId ?? this.customerId,
      doctorId: doctorId ?? this.doctorId,
      registrationDate: registrationDate ?? this.registrationDate,
      complaint: complaint ?? this.complaint,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      doctorName: doctorName ?? this.doctorName,
    );
  }
}
