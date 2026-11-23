import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../core/demo_credentials.dart';
import '../models/app_models.dart';
import 'parking_repository.dart';

class DemoParkingRepository implements ParkingRepository {
  DemoParkingRepository() {
    _seedDemoData();
    _profile = _customers.first;
  }

  final StreamController<Object?> _changes =
      StreamController<Object?>.broadcast();

  final List<AppUser> _customers = [
    AppUser(
      id: 'demo-customer',
      name: 'Demo Customer',
      email: DemoCredentials.customerEmail,
      phone: '9876543210',
      role: 'customer',
      createdAt: DateTime.now(),
    ),
  ];
  final List<ParkingLocation> _locations = [];
  final List<ParkingSlot> _slots = [];
  final List<Booking> _bookings = [];
  final List<PaymentRecord> _payments = [];
  final List<AppNotification> _notifications = [];
  final List<Complaint> _complaints = [];
  final Map<String, String> _customerPasswords = {
    DemoCredentials.customerEmail: DemoCredentials.customerPassword,
  };

  AppUser? _profile;
  int _nextId = 100;

  @override
  Stream<Object?> get authStateChanges => _changes.stream;

  @override
  bool isPasswordRecoveryEvent(Object? event) => false;

  String _id(String prefix) => '$prefix-${_nextId++}';

  void _notify() => _changes.add(null);

  Stream<List<T>> _watch<T>(List<T> Function() read) async* {
    yield List<T>.unmodifiable(read());
    await for (final _ in _changes.stream) {
      yield List<T>.unmodifiable(read());
    }
  }

  @override
  Future<AppUser?> getSignedInProfile() async => _profile;

  @override
  Future<void> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_customerPasswords.containsKey(normalizedEmail)) {
      throw StateError('An account already exists with this email.');
    }
    final customer = AppUser(
      id: _id('customer'),
      name: name,
      email: normalizedEmail,
      phone: phone,
      role: 'customer',
      createdAt: DateTime.now(),
    );
    _customers.add(customer);
    _customerPasswords[normalizedEmail] = password;
    _profile = customer;
    _notify();
  }

  @override
  Future<void> signInCustomer({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (_customerPasswords[normalized] != password) {
      throw StateError('Invalid customer email or password.');
    }
    _profile = _customers.where((user) => user.email == normalized).firstOrNull;
    _notify();
  }

  @override
  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {
    if (email.trim().toLowerCase() != DemoCredentials.adminEmail ||
        password != DemoCredentials.adminPassword) {
      throw StateError('Invalid admin email or password.');
    }
    _profile = AppUser(
      id: 'demo-admin',
      name: 'QuickParking Admin',
      email: DemoCredentials.adminEmail,
      phone: '9999999999',
      role: 'admin',
      createdAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    throw StateError(
      'Password reset email is unavailable in local demo mode. '
      'Connect Supabase to test real password recovery.',
    );
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final email = _profile?.email;
    if (email == null || !_customerPasswords.containsKey(email)) {
      throw StateError('Please sign in before updating your password.');
    }
    _customerPasswords[email] = newPassword;
  }

  @override
  Future<void> signOut() async {
    _profile = null;
    _notify();
  }

  @override
  Stream<List<ParkingLocation>> parkingLocations({String query = ''}) {
    return _watch(() {
      final needle = query.trim().toLowerCase();
      if (needle.isEmpty) {
        return _locations;
      }
      return _locations
          .where(
            (location) =>
                location.name.toLowerCase().contains(needle) ||
                location.address.toLowerCase().contains(needle) ||
                location.city.toLowerCase().contains(needle),
          )
          .toList();
    });
  }

  @override
  Stream<List<ParkingSlot>> slotsForLocation(String locationId) {
    return _watch(
      () =>
          _slots.where((slot) => slot.locationId == locationId).toList()
            ..sort((a, b) => a.slotNumber.compareTo(b.slotNumber)),
    );
  }

  @override
  Stream<List<Booking>> bookingsForCustomer(String userId) {
    return _watch(
      () =>
          _bookings.where((booking) => booking.userId == userId).toList()
            ..sort((a, b) => b.startTime.compareTo(a.startTime)),
    );
  }

  @override
  Stream<List<Booking>> allBookings() {
    return _watch(
      () =>
          List<Booking>.from(_bookings)
            ..sort((a, b) => b.startTime.compareTo(a.startTime)),
    );
  }

  @override
  Stream<List<AppUser>> allCustomers() {
    return _watch(
      () =>
          List<AppUser>.from(_customers)
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  @override
  Stream<List<PaymentRecord>> allPayments() {
    return _watch(
      () => List<PaymentRecord>.from(_payments)
        ..sort(
          (a, b) =>
              (b.paidAt ?? DateTime(0)).compareTo(a.paidAt ?? DateTime(0)),
        ),
    );
  }

  @override
  Stream<List<AppNotification>> notificationsForCurrentUser() {
    return _watch(
      () =>
          _notifications
              .where((notification) => notification.userId == _profile?.id)
              .toList()
            ..sort(
              (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                a.createdAt ?? DateTime(0),
              ),
            ),
    );
  }

  @override
  Stream<List<Complaint>> allComplaints() {
    return _watch(
      () => List<Complaint>.from(_complaints)
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        ),
    );
  }

  @override
  Future<double> calculatePrice({
    required ParkingLocation location,
    required ParkingSlot slot,
    required int durationHours,
  }) async {
    final hourly = slot.type == 'free'
        ? 0.0
        : (slot.ratePerHour > 0 ? slot.ratePerHour : location.baseRate);
    return hourly * durationHours;
  }

  @override
  Future<Booking> createBooking({
    required ParkingLocation location,
    required ParkingSlot slot,
    required DateTime startTime,
    required int durationHours,
    required String vehicleNumber,
  }) async {
    final user = _profile;
    if (user == null || user.isAdmin) {
      throw StateError('Please log in as a customer before booking.');
    }
    if (durationHours < 1 || durationHours > 24) {
      throw StateError('Duration must be between 1 and 24 hours.');
    }
    if (!RegExp(r'^[A-Za-z0-9]{10}$').hasMatch(vehicleNumber.trim())) {
      throw StateError(
        'Vehicle number must contain exactly 10 letters and numbers.',
      );
    }
    if (startTime.isBefore(
      DateTime.now().subtract(const Duration(minutes: 1)),
    )) {
      throw StateError('Please select a future booking date and time.');
    }
    final slotIndex = _slots.indexWhere((item) => item.id == slot.id);
    if (slotIndex < 0 || !_slots[slotIndex].isAvailable) {
      throw StateError('Selected slot is no longer available.');
    }
    final locationIndex = _locations.indexWhere(
      (item) => item.id == location.id,
    );
    final amount = await calculatePrice(
      location: location,
      slot: slot,
      durationHours: durationHours,
    );
    final bookingId = _id('booking');
    final bookingCode =
        'QP${DateTime.now().millisecondsSinceEpoch % 100000000}';
    final booking = Booking(
      id: bookingId,
      bookingCode: bookingCode,
      userId: user.id,
      locationId: location.id,
      locationName: location.name,
      slotId: slot.id,
      slotNumber: slot.slotNumber,
      startTime: startTime,
      endTime: startTime.add(Duration(hours: durationHours)),
      durationHours: durationHours,
      status: 'reserved',
      amount: amount,
      paymentStatus: 'pending',
      qrPayload: 'BOOKING:$bookingCode|ID:$bookingId|SLOT:${slot.slotNumber}',
      vehicleNumber: vehicleNumber.toUpperCase(),
      createdAt: DateTime.now(),
    );
    _bookings.add(booking);
    _slots[slotIndex] = _copySlot(
      _slots[slotIndex],
      status: 'reserved',
      currentBookingId: booking.id,
    );
    if (locationIndex >= 0) {
      final current = _locations[locationIndex];
      _locations[locationIndex] = _copyLocation(
        current,
        availableSlots: (current.availableSlots - 1).clamp(
          0,
          current.totalSlots,
        ),
      );
    }
    _addNotification(
      user.id,
      'Booking created',
      'Slot ${slot.slotNumber} at ${location.name} has been reserved.',
      'booking',
    );
    _notify();
    return booking;
  }

  @override
  Future<void> recordDemoPayment({
    required Booking booking,
    String method = 'UPI',
  }) async {
    final index = _bookings.indexWhere((item) => item.id == booking.id);
    if (index < 0) {
      throw StateError('Booking not found.');
    }
    _bookings[index] = _copyBooking(
      _bookings[index],
      status: 'confirmed',
      paymentStatus: 'paid',
    );
    _payments.add(
      PaymentRecord(
        id: _id('payment'),
        bookingId: booking.id,
        userId: booking.userId,
        amount: booking.amount,
        method: method,
        status: 'success',
        paidAt: DateTime.now(),
      ),
    );
    _addNotification(
      booking.userId,
      'Payment successful',
      'Payment received for ${booking.bookingCode}. Your QR pass is ready.',
      'payment',
    );
    _notify();
  }

  @override
  Future<Booking> createBookingAndPay({
    required ParkingLocation location,
    required ParkingSlot slot,
    required DateTime startTime,
    required int durationHours,
    required String vehicleNumber,
    required String paymentMethod,
  }) async {
    final booking = await createBooking(
      location: location,
      slot: slot,
      startTime: startTime,
      durationHours: durationHours,
      vehicleNumber: vehicleNumber,
    );
    await recordDemoPayment(booking: booking, method: paymentMethod);
    return _bookings.firstWhere((item) => item.id == booking.id);
  }

  @override
  Future<void> verifyBookingFlow(
    String codeOrPayload, {
    required bool checkIn,
  }) async {
    final code = codeOrPayload.contains('BOOKING:')
        ? codeOrPayload.split('|').first.replaceFirst('BOOKING:', '').trim()
        : codeOrPayload.trim();
    final bookingIndex = _bookings.indexWhere(
      (booking) => booking.bookingCode.toUpperCase() == code.toUpperCase(),
    );
    if (bookingIndex < 0) {
      throw StateError('Booking code not found.');
    }
    final booking = _bookings[bookingIndex];
    final slotIndex = _slots.indexWhere((slot) => slot.id == booking.slotId);
    if (checkIn) {
      if (booking.paymentStatus != 'paid' || booking.status != 'confirmed') {
        throw StateError('Only a paid, confirmed booking can be checked in.');
      }
      _bookings[bookingIndex] = _copyBooking(
        booking,
        status: 'active',
        checkedInAt: DateTime.now(),
      );
      if (slotIndex >= 0) {
        _slots[slotIndex] = _copySlot(_slots[slotIndex], status: 'occupied');
      }
    } else {
      if (booking.status != 'active') {
        throw StateError('Only active bookings can be checked out.');
      }
      _bookings[bookingIndex] = _copyBooking(
        booking,
        status: 'completed',
        checkedOutAt: DateTime.now(),
      );
      if (slotIndex >= 0) {
        _slots[slotIndex] = _copySlot(
          _slots[slotIndex],
          status: 'available',
          currentBookingId: '',
        );
      }
      final locationIndex = _locations.indexWhere(
        (location) => location.id == booking.locationId,
      );
      if (locationIndex >= 0) {
        final location = _locations[locationIndex];
        _locations[locationIndex] = _copyLocation(
          location,
          availableSlots: (location.availableSlots + 1).clamp(
            0,
            location.totalSlots,
          ),
        );
      }
    }
    _addNotification(
      booking.userId,
      checkIn ? 'Vehicle checked in' : 'Vehicle checked out',
      'Booking ${booking.bookingCode} was verified successfully.',
      'verification',
    );
    _notify();
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String phone,
    String? email,
    String? profileImageUrl,
  }) async {
    final profile = _profile;
    if (profile == null) {
      throw StateError('Please sign in before updating your profile.');
    }
    final updated = AppUser(
      id: profile.id,
      name: name,
      email: email?.trim().isNotEmpty == true ? email!.trim() : profile.email,
      phone: phone,
      role: profile.role,
      profileImageUrl: profileImageUrl ?? profile.profileImageUrl,
      createdAt: profile.createdAt,
    );
    _profile = updated;
    final index = _customers.indexWhere((user) => user.id == profile.id);
    if (index >= 0) {
      _customers[index] = updated;
    }
    _notify();
  }

  @override
  Future<void> reauthenticate(String password) async {
    if (password.length < 6) {
      throw StateError('Enter your current password to continue.');
    }
  }

  @override
  Future<void> deleteProfileImage(String imageUrl) async {}

  @override
  Future<void> markNotificationRead(String notificationId) async {
    final index = _notifications.indexWhere(
      (notification) => notification.id == notificationId,
    );
    if (index >= 0) {
      final current = _notifications[index];
      _notifications[index] = AppNotification(
        id: current.id,
        userId: current.userId,
        title: current.title,
        message: current.message,
        type: current.type,
        read: true,
        createdAt: current.createdAt,
      );
      _notify();
    }
  }

  @override
  Future<void> submitComplaint({
    required String subject,
    required String message,
  }) async {
    final user = _profile;
    if (user == null) {
      throw StateError('Please sign in before sending a complaint.');
    }
    _complaints.add(
      Complaint(
        id: _id('complaint'),
        userId: user.id,
        subject: subject,
        message: message,
        status: 'open',
        createdAt: DateTime.now(),
      ),
    );
    _notify();
  }

  @override
  Future<String> uploadImage({
    required PlatformFile file,
    required String folder,
  }) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError('Selected file could not be read.');
    }
    final extension = file.extension?.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(extension)) {
      throw StateError('Choose a JPG, PNG, GIF, or WebP image.');
    }
    final contentType = extension == 'jpg' || extension == 'jpeg'
        ? 'image/jpeg'
        : 'image/${extension ?? 'png'}';
    return 'data:$contentType;base64,${base64Encode(bytes)}';
  }

  @override
  Future<void> createOrUpdateLocation({
    String? locationId,
    required String name,
    required String address,
    required String city,
    required String description,
    required String contactNumber,
    required double baseRate,
    required int totalSlots,
    required String openingHours,
    required String imageUrl,
  }) async {
    final index = _locations.indexWhere(
      (location) => location.id == locationId,
    );
    final available = index < 0
        ? totalSlots
        : _locations[index].availableSlots.clamp(0, totalSlots);
    final location = ParkingLocation(
      id: locationId ?? _id('location'),
      name: name,
      address: address,
      city: city,
      baseRate: baseRate,
      totalSlots: totalSlots,
      availableSlots: available,
      imageUrl: imageUrl,
      description: description,
      contactNumber: contactNumber,
      openingHours: openingHours,
    );
    if (index < 0) {
      _locations.add(location);
    } else {
      _locations[index] = location;
    }
    _notify();
  }

  @override
  Future<void> createOrUpdateSlot({
    String? slotId,
    required String locationId,
    required String slotNumber,
    required String floor,
    required String type,
    required String status,
    required String vehicleType,
    required double ratePerHour,
  }) async {
    final index = _slots.indexWhere((slot) => slot.id == slotId);
    final slot = ParkingSlot(
      id: slotId ?? _id('slot'),
      locationId: locationId,
      slotNumber: slotNumber,
      floor: floor,
      type: type,
      status: status,
      vehicleType: vehicleType,
      ratePerHour: ratePerHour,
      currentBookingId: index < 0 ? '' : _slots[index].currentBookingId,
    );
    if (index < 0) {
      _slots.add(slot);
    } else {
      _slots[index] = slot;
    }
    _notify();
  }

  @override
  Future<void> updateBookingStatus(String bookingId, String status) async {
    const statuses = {
      'reserved',
      'confirmed',
      'active',
      'completed',
      'cancelled',
    };
    if (!statuses.contains(status)) {
      throw StateError('Invalid booking status.');
    }
    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index < 0) {
      throw StateError('Booking not found.');
    }
    final booking = _bookings[index];
    if (booking.status == status) {
      return;
    }
    if (booking.status == 'completed' || booking.status == 'cancelled') {
      throw StateError('Completed or cancelled bookings cannot be reopened.');
    }
    if (status == 'active' && booking.paymentStatus != 'paid') {
      throw StateError('Only a paid booking can be marked active.');
    }

    final slotIndex = _slots.indexWhere((slot) => slot.id == booking.slotId);
    if (slotIndex < 0) {
      throw StateError('Parking slot not found.');
    }
    final slot = _slots[slotIndex];
    if (slot.currentBookingId.isNotEmpty &&
        slot.currentBookingId != booking.id) {
      throw StateError('The parking slot belongs to another booking.');
    }

    final terminalStatus = status == 'completed' || status == 'cancelled';
    if (terminalStatus && slot.currentBookingId == booking.id) {
      _slots[slotIndex] = _copySlot(
        slot,
        status: 'available',
        currentBookingId: '',
      );
      final locationIndex = _locations.indexWhere(
        (location) => location.id == booking.locationId,
      );
      if (locationIndex >= 0) {
        final location = _locations[locationIndex];
        _locations[locationIndex] = _copyLocation(
          location,
          availableSlots: (location.availableSlots + 1).clamp(
            0,
            location.totalSlots,
          ),
        );
      }
    } else if (!terminalStatus) {
      _slots[slotIndex] = _copySlot(
        slot,
        status: status == 'active' ? 'occupied' : 'reserved',
        currentBookingId: booking.id,
      );
    }

    _bookings[index] = _copyBooking(
      booking,
      status: status,
      checkedInAt: status == 'active' ? DateTime.now() : null,
      checkedOutAt: status == 'completed' ? DateTime.now() : null,
    );
    _notify();
  }

  @override
  Future<void> deleteDocument(String collection, String id) async {
    if (collection == 'parking_locations') {
      _locations.removeWhere((location) => location.id == id);
      _slots.removeWhere((slot) => slot.locationId == id);
    } else if (collection == 'parking_slots') {
      _slots.removeWhere((slot) => slot.id == id);
    } else {
      throw ArgumentError.value(collection, 'collection', 'Unsupported table');
    }
    _notify();
  }

  @override
  Future<void> seedDemoData() async {
    if (_locations.isEmpty) {
      _seedDemoData();
      _notify();
    }
  }

  void _seedDemoData() {
    const cityId = 'location-city-centre';
    const mallId = 'location-riverfront';
    _locations.addAll(const [
      ParkingLocation(
        id: cityId,
        name: 'City Centre Parking',
        address: 'MG Road, Downtown',
        city: 'Ahmedabad',
        baseRate: 30,
        totalSlots: 6,
        availableSlots: 6,
        description: 'Covered smart parking with CCTV and EV charging.',
        contactNumber: '+91 98989 00001',
        openingHours: '06:00 AM - 11:30 PM',
      ),
      ParkingLocation(
        id: mallId,
        name: 'Riverfront Mall Parking',
        address: 'Sabarmati Riverfront',
        city: 'Ahmedabad',
        baseRate: 40,
        totalSlots: 6,
        availableSlots: 6,
        description: 'Multi-level parking close to shopping and entertainment.',
        contactNumber: '+91 98989 00002',
      ),
    ]);
    _slots.addAll(const [
      ParkingSlot(
        id: 'slot-a1',
        locationId: cityId,
        slotNumber: 'A1',
        floor: 'Ground',
        type: 'paid',
        status: 'available',
        ratePerHour: 30,
      ),
      ParkingSlot(
        id: 'slot-a2',
        locationId: cityId,
        slotNumber: 'A2',
        floor: 'Ground',
        type: 'paid',
        status: 'available',
        ratePerHour: 30,
      ),
      ParkingSlot(
        id: 'slot-a3',
        locationId: cityId,
        slotNumber: 'A3',
        floor: 'Ground',
        type: 'free',
        status: 'available',
        ratePerHour: 0,
        vehicleType: 'Bike',
      ),
      ParkingSlot(
        id: 'slot-e1',
        locationId: cityId,
        slotNumber: 'E1',
        floor: 'First',
        type: 'paid',
        status: 'available',
        ratePerHour: 45,
        vehicleType: 'EV',
      ),
      ParkingSlot(
        id: 'slot-b1',
        locationId: cityId,
        slotNumber: 'B1',
        floor: 'First',
        type: 'paid',
        status: 'available',
        ratePerHour: 30,
      ),
      ParkingSlot(
        id: 'slot-b2',
        locationId: cityId,
        slotNumber: 'B2',
        floor: 'First',
        type: 'paid',
        status: 'available',
        ratePerHour: 30,
      ),
      ParkingSlot(
        id: 'slot-m1',
        locationId: mallId,
        slotNumber: 'M1',
        floor: 'Basement 1',
        type: 'paid',
        status: 'available',
        ratePerHour: 40,
      ),
      ParkingSlot(
        id: 'slot-m2',
        locationId: mallId,
        slotNumber: 'M2',
        floor: 'Basement 1',
        type: 'paid',
        status: 'available',
        ratePerHour: 40,
      ),
      ParkingSlot(
        id: 'slot-m3',
        locationId: mallId,
        slotNumber: 'M3',
        floor: 'Basement 1',
        type: 'paid',
        status: 'available',
        ratePerHour: 20,
        vehicleType: 'Bike',
      ),
      ParkingSlot(
        id: 'slot-m4',
        locationId: mallId,
        slotNumber: 'M4',
        floor: 'Basement 2',
        type: 'paid',
        status: 'available',
        ratePerHour: 40,
      ),
      ParkingSlot(
        id: 'slot-m5',
        locationId: mallId,
        slotNumber: 'M5',
        floor: 'Basement 2',
        type: 'paid',
        status: 'available',
        ratePerHour: 55,
        vehicleType: 'EV',
      ),
      ParkingSlot(
        id: 'slot-m6',
        locationId: mallId,
        slotNumber: 'M6',
        floor: 'Basement 2',
        type: 'free',
        status: 'available',
        ratePerHour: 0,
        vehicleType: 'Bike',
      ),
    ]);
  }

  void _addNotification(
    String userId,
    String title,
    String message,
    String type,
  ) {
    _notifications.add(
      AppNotification(
        id: _id('notification'),
        userId: userId,
        title: title,
        message: message,
        type: type,
        read: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  ParkingLocation _copyLocation(
    ParkingLocation location, {
    int? availableSlots,
  }) {
    return ParkingLocation(
      id: location.id,
      name: location.name,
      address: location.address,
      city: location.city,
      baseRate: location.baseRate,
      totalSlots: location.totalSlots,
      availableSlots: availableSlots ?? location.availableSlots,
      imageUrl: location.imageUrl,
      description: location.description,
      contactNumber: location.contactNumber,
      openingHours: location.openingHours,
    );
  }

  ParkingSlot _copySlot(
    ParkingSlot slot, {
    String? status,
    String? currentBookingId,
  }) {
    return ParkingSlot(
      id: slot.id,
      locationId: slot.locationId,
      slotNumber: slot.slotNumber,
      floor: slot.floor,
      type: slot.type,
      status: status ?? slot.status,
      ratePerHour: slot.ratePerHour,
      currentBookingId: currentBookingId ?? slot.currentBookingId,
      vehicleType: slot.vehicleType,
    );
  }

  Booking _copyBooking(
    Booking booking, {
    String? status,
    String? paymentStatus,
    DateTime? checkedInAt,
    DateTime? checkedOutAt,
  }) {
    return Booking(
      id: booking.id,
      bookingCode: booking.bookingCode,
      userId: booking.userId,
      locationId: booking.locationId,
      locationName: booking.locationName,
      slotId: booking.slotId,
      slotNumber: booking.slotNumber,
      startTime: booking.startTime,
      endTime: booking.endTime,
      durationHours: booking.durationHours,
      status: status ?? booking.status,
      amount: booking.amount,
      paymentStatus: paymentStatus ?? booking.paymentStatus,
      qrPayload: booking.qrPayload,
      vehicleNumber: booking.vehicleNumber,
      createdAt: booking.createdAt,
      checkedInAt: checkedInAt ?? booking.checkedInAt,
      checkedOutAt: checkedOutAt ?? booking.checkedOutAt,
    );
  }
}
