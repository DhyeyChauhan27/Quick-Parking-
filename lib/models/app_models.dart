DateTime? dateTimeFromDynamic(dynamic value) {
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImageUrl = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String profileImageUrl;
  final DateTime? createdAt;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      name: map['name'] as String? ?? 'User',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: map['role'] as String? ?? 'customer',
      profileImageUrl: map['profile_image_url'] as String? ?? '',
      createdAt: dateTimeFromDynamic(map['created_at']),
    );
  }
}

class ParkingLocation {
  const ParkingLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.baseRate,
    required this.totalSlots,
    required this.availableSlots,
    this.imageUrl = '',
    this.description = '',
    this.contactNumber = '',
    this.openingHours = '24/7',
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final double baseRate;
  final int totalSlots;
  final int availableSlots;
  final String imageUrl;
  final String description;
  final String contactNumber;
  final String openingHours;

  factory ParkingLocation.fromMap(String id, Map<String, dynamic> map) {
    return ParkingLocation(
      id: id,
      name: map['name'] as String? ?? 'Location',
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
      baseRate: (map['base_rate'] as num?)?.toDouble() ?? 0,
      totalSlots: (map['total_slots'] as num?)?.toInt() ?? 0,
      availableSlots: (map['available_slots'] as num?)?.toInt() ?? 0,
      imageUrl: map['image_url'] as String? ?? '',
      description: map['description'] as String? ?? '',
      contactNumber: map['contact_number'] as String? ?? '',
      openingHours: map['opening_hours'] as String? ?? '24/7',
    );
  }
}

class ParkingSlot {
  const ParkingSlot({
    required this.id,
    required this.locationId,
    required this.slotNumber,
    required this.floor,
    required this.type,
    required this.status,
    required this.ratePerHour,
    this.currentBookingId = '',
    this.vehicleType = 'Car',
  });

  final String id;
  final String locationId;
  final String slotNumber;
  final String floor;
  final String type;
  final String status;
  final double ratePerHour;
  final String currentBookingId;
  final String vehicleType;

  bool get isAvailable => status == 'available';

  factory ParkingSlot.fromMap(String id, Map<String, dynamic> map) {
    return ParkingSlot(
      id: id,
      locationId: map['location_id'] as String? ?? '',
      slotNumber: map['slot_number'] as String? ?? '',
      floor: map['floor'] as String? ?? 'Ground',
      type: map['type'] as String? ?? 'paid',
      status: map['status'] as String? ?? 'available',
      ratePerHour: (map['rate_per_hour'] as num?)?.toDouble() ?? 0,
      currentBookingId: map['current_booking_id'] as String? ?? '',
      vehicleType: map['vehicle_type'] as String? ?? 'Car',
    );
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.bookingCode,
    required this.userId,
    required this.locationId,
    required this.locationName,
    required this.slotId,
    required this.slotNumber,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.status,
    required this.amount,
    required this.paymentStatus,
    required this.qrPayload,
    required this.vehicleNumber,
    this.createdAt,
    this.checkedInAt,
    this.checkedOutAt,
  });

  final String id;
  final String bookingCode;
  final String userId;
  final String locationId;
  final String locationName;
  final String slotId;
  final String slotNumber;
  final DateTime startTime;
  final DateTime endTime;
  final int durationHours;
  final String status;
  final double amount;
  final String paymentStatus;
  final String qrPayload;
  final String vehicleNumber;
  final DateTime? createdAt;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;

  factory Booking.fromMap(String id, Map<String, dynamic> map) {
    final start = dateTimeFromDynamic(map['start_time']) ?? DateTime.now();
    final end =
        dateTimeFromDynamic(map['end_time']) ??
        start.add(const Duration(hours: 1));
    return Booking(
      id: id,
      bookingCode: map['booking_code'] as String? ?? id,
      userId: map['user_id'] as String? ?? '',
      locationId: map['location_id'] as String? ?? '',
      locationName: map['location_name'] as String? ?? '',
      slotId: map['slot_id'] as String? ?? '',
      slotNumber: map['slot_number'] as String? ?? '',
      startTime: start,
      endTime: end,
      durationHours: (map['duration_hours'] as num?)?.toInt() ?? 1,
      status: map['status'] as String? ?? 'confirmed',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paymentStatus: map['payment_status'] as String? ?? 'pending',
      qrPayload: map['qr_payload'] as String? ?? '',
      vehicleNumber: map['vehicle_number'] as String? ?? '',
      createdAt: dateTimeFromDynamic(map['created_at']),
      checkedInAt: dateTimeFromDynamic(map['checked_in_at']),
      checkedOutAt: dateTimeFromDynamic(map['checked_out_at']),
    );
  }
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.amount,
    required this.method,
    required this.status,
    this.paidAt,
  });

  final String id;
  final String bookingId;
  final String userId;
  final double amount;
  final String method;
  final String status;
  final DateTime? paidAt;

  factory PaymentRecord.fromMap(String id, Map<String, dynamic> map) {
    return PaymentRecord(
      id: id,
      bookingId: map['booking_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      method: map['method'] as String? ?? 'UPI',
      status: map['status'] as String? ?? 'success',
      paidAt: dateTimeFromDynamic(map['paid_at']),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      userId: map['user_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      type: map['type'] as String? ?? 'general',
      read: map['read'] as bool? ?? false,
      createdAt: dateTimeFromDynamic(map['created_at']),
    );
  }
}

class Complaint {
  const Complaint({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String subject;
  final String message;
  final String status;
  final DateTime? createdAt;

  factory Complaint.fromMap(String id, Map<String, dynamic> map) {
    return Complaint(
      id: id,
      userId: map['user_id'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      message: map['message'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      createdAt: dateTimeFromDynamic(map['created_at']),
    );
  }
}
