import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_models.dart';
import '../supabase_options.dart';
import 'parking_repository.dart';

class SupabaseParkingRepository implements ParkingRepository {
  SupabaseParkingRepository({this.client, this.supabaseEnabled = true});

  final SupabaseClient? client;
  final bool supabaseEnabled;

  SupabaseClient get _supabase {
    _ensureEnabled();
    return client ?? Supabase.instance.client;
  }

  @override
  Stream<AuthState> get authStateChanges {
    if (!supabaseEnabled) {
      return const Stream<AuthState>.empty();
    }
    return _supabase.auth.onAuthStateChange;
  }

  @override
  bool isPasswordRecoveryEvent(Object? event) {
    return event is AuthState &&
        event.event == AuthChangeEvent.passwordRecovery;
  }

  User? get currentUser => supabaseEnabled ? _supabase.auth.currentUser : null;

  void _ensureEnabled() {
    if (!supabaseEnabled) {
      throw StateError(
        'Supabase is not configured yet. Follow SUPABASE_SETUP.md first.',
      );
    }
  }

  Map<String, dynamic> _row(dynamic value) {
    return Map<String, dynamic>.from(value as Map);
  }

  Map<String, dynamic> _rpcRow(dynamic value) {
    if (value is List) {
      if (value.isEmpty) {
        throw StateError('The database operation did not return a result.');
      }
      return _row(value.first);
    }
    return _row(value);
  }

  @override
  Future<AppUser?> getSignedInProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return null;
    }

    final admin = await _supabase
        .from('admins')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (admin != null) {
      return AppUser.fromMap(user.id, admin);
    }

    final customer = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (customer != null) {
      return AppUser.fromMap(user.id, customer);
    }
    return null;
  }

  @override
  Future<void> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'phone': phone, 'role': 'customer'},
    );
    if (response.user == null) {
      throw StateError('Supabase could not create the customer account.');
    }
  }

  @override
  Future<void> signInCustomer({
    required String email,
    required String password,
  }) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
    final profile = await getSignedInProfile();
    if (profile == null || profile.role != 'customer') {
      await _supabase.auth.signOut();
      throw StateError('This account is not registered as a customer.');
    }
  }

  @override
  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
    final profile = await getSignedInProfile();
    if (profile == null || !profile.isAdmin) {
      await _supabase.auth.signOut();
      throw StateError('This account does not have admin access.');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      final redirectUrl = SupabaseOptions.passwordResetRedirectUrl.trim();
      if (redirectUrl.isEmpty) {
        await _supabase.auth.resetPasswordForEmail(email);
        return;
      }
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );
    } on AuthException catch (error) {
      if (error.code == 'email_address_invalid') {
        throw StateError(
          'Reset email cannot be delivered to this address. '
          'Use your real registered inbox email, not the demo customer email.',
        );
      }
      if (error.statusCode == '429') {
        throw StateError(
          'Too many reset emails were requested. Please wait one minute '
          'before requesting another link.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> reauthenticate(String password) async {
    final user = _supabase.auth.currentUser;
    final email = user?.email?.trim() ?? '';
    if (email.isEmpty) {
      throw StateError(
        'Your account email is unavailable. Please sign in again.',
      );
    }
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _supabase.auth.signOut();

  @override
  Stream<List<ParkingLocation>> parkingLocations({String query = ''}) {
    return _supabase
        .from('parking_locations')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map((rows) {
          final locations = rows
              .map((row) => ParkingLocation.fromMap(row['id'] as String, row))
              .toList();
          final needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return locations;
          }
          return locations
              .where(
                (item) =>
                    item.name.toLowerCase().contains(needle) ||
                    item.address.toLowerCase().contains(needle) ||
                    item.city.toLowerCase().contains(needle),
              )
              .toList();
        });
  }

  @override
  Stream<List<ParkingSlot>> slotsForLocation(String locationId) {
    return _supabase
        .from('parking_slots')
        .stream(primaryKey: ['id'])
        .eq('location_id', locationId)
        .order('slot_number', ascending: true)
        .map(
          (rows) => rows
              .map((row) => ParkingSlot.fromMap(row['id'] as String, row))
              .toList(),
        );
  }

  @override
  Stream<List<Booking>> bookingsForCustomer(String userId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('start_time', ascending: false)
        .map(
          (rows) => rows
              .map((row) => Booking.fromMap(row['id'] as String, row))
              .toList(),
        );
  }

  @override
  Stream<List<Booking>> allBookings() {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .order('start_time', ascending: false)
        .map(
          (rows) => rows
              .map((row) => Booking.fromMap(row['id'] as String, row))
              .toList(),
        );
  }

  @override
  Stream<List<AppUser>> allCustomers() {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map(
          (rows) => rows
              .map((row) => AppUser.fromMap(row['id'] as String, row))
              .toList(),
        );
  }

  @override
  Stream<List<PaymentRecord>> allPayments() {
    return _supabase
        .from('payments')
        .stream(primaryKey: ['id'])
        .order('paid_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) => PaymentRecord.fromMap(row['id'] as String, row))
              .toList(),
        );
  }

  @override
  Stream<List<AppNotification>> notificationsForCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const Stream<List<AppNotification>>.empty();
    }
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) => AppNotification.fromMap(row['id'] as String, row))
              .toList(),
        );
  }

  @override
  Stream<List<Complaint>> allComplaints() {
    return _supabase
        .from('complaints')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) => Complaint.fromMap(row['id'] as String, row))
              .toList(),
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
    final response = await _supabase.rpc(
      'create_booking',
      params: {
        'p_location_id': location.id,
        'p_slot_id': slot.id,
        'p_start_time': startTime.toUtc().toIso8601String(),
        'p_duration_hours': durationHours,
        'p_vehicle_number': vehicleNumber,
      },
    );
    final row = _rpcRow(response);
    return Booking.fromMap(row['id'] as String, row);
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
    final response = await _supabase.rpc(
      'create_booking_and_pay',
      params: {
        'p_location_id': location.id,
        'p_slot_id': slot.id,
        'p_start_time': startTime.toUtc().toIso8601String(),
        'p_duration_hours': durationHours,
        'p_vehicle_number': vehicleNumber,
        'p_method': paymentMethod,
      },
    );
    final row = _rpcRow(response);
    return Booking.fromMap(row['id'] as String, row);
  }

  @override
  Future<void> recordDemoPayment({
    required Booking booking,
    String method = 'UPI',
  }) async {
    await _supabase.rpc(
      'record_demo_payment',
      params: {'p_booking_id': booking.id, 'p_method': method},
    );
  }

  @override
  Future<void> verifyBookingFlow(
    String codeOrPayload, {
    required bool checkIn,
  }) async {
    final code = codeOrPayload.contains('BOOKING:')
        ? codeOrPayload.split('|').first.replaceFirst('BOOKING:', '').trim()
        : codeOrPayload.trim();
    await _supabase.rpc(
      'verify_booking_flow',
      params: {'p_booking_code': code, 'p_check_in': checkIn},
    );
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String phone,
    String? email,
    String? profileImageUrl,
  }) async {
    final profile = await getSignedInProfile();
    if (profile == null) {
      throw StateError('Please sign in before updating your profile.');
    }
    final table = profile.isAdmin ? 'admins' : 'users';
    final requestedEmail = email?.trim().toLowerCase();
    final emailChanged =
        requestedEmail != null &&
        requestedEmail.isNotEmpty &&
        requestedEmail != profile.email;
    await _supabase.auth.updateUser(
      UserAttributes(
        email: emailChanged ? requestedEmail : null,
        data: {
          'name': name,
          'phone': phone,
          if (emailChanged) 'email': requestedEmail,
        },
      ),
    );
    final data = <String, dynamic>{'name': name, 'phone': phone};
    if (emailChanged) {
      data['email'] = requestedEmail;
    }
    if (profileImageUrl != null) {
      data['profile_image_url'] = profileImageUrl;
    }
    await _supabase.from(table).update(data).eq('id', profile.id);
  }

  @override
  Future<void> deleteProfileImage(String imageUrl) async {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) {
      return;
    }
    final bucketIndex = uri.pathSegments.indexOf('parking-images');
    if (bucketIndex < 0 || bucketIndex >= uri.pathSegments.length - 1) {
      return;
    }
    final path = uri.pathSegments.skip(bucketIndex + 1).join('/');
    if (!path.startsWith('profile-images/')) {
      return;
    }
    await _supabase.storage.from('parking-images').remove([path]);
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'read': true})
        .eq('id', notificationId);
  }

  @override
  Future<void> submitComplaint({
    required String subject,
    required String message,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in before sending a complaint.');
    }
    await _supabase.from('complaints').insert({
      'user_id': user.id,
      'subject': subject,
      'message': message,
    });
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
    const imageContentTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
    };
    final extension = file.extension?.toLowerCase();
    if (!imageContentTypes.containsKey(extension)) {
      throw StateError('Choose a JPG, PNG, GIF, or WebP image.');
    }
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _supabase.storage
        .from('parking-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType:
                imageContentTypes[extension] ?? 'application/octet-stream',
          ),
        );
    return _supabase.storage.from('parking-images').getPublicUrl(path);
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
    final data = <String, dynamic>{
      'name': name,
      'address': address,
      'city': city,
      'description': description,
      'contact_number': contactNumber,
      'base_rate': baseRate,
      'total_slots': totalSlots,
      'opening_hours': openingHours,
      'image_url': imageUrl,
    };
    if (locationId == null) {
      data['available_slots'] = totalSlots;
      await _supabase.from('parking_locations').insert(data);
      return;
    }

    final existing = await _supabase
        .from('parking_locations')
        .select('available_slots')
        .eq('id', locationId)
        .single();
    final available = (existing['available_slots'] as num?)?.toInt() ?? 0;
    data['available_slots'] = available.clamp(0, totalSlots);
    await _supabase.from('parking_locations').update(data).eq('id', locationId);
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
    final data = <String, dynamic>{
      'location_id': locationId,
      'slot_number': slotNumber,
      'floor': floor,
      'type': type,
      'status': status,
      'vehicle_type': vehicleType,
      'rate_per_hour': ratePerHour,
    };
    if (slotId == null) {
      await _supabase.from('parking_slots').insert(data);
    } else {
      await _supabase.from('parking_slots').update(data).eq('id', slotId);
    }
  }

  @override
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _supabase.rpc(
      'update_booking_status',
      params: {'p_booking_id': bookingId, 'p_status': status},
    );
  }

  @override
  Future<void> deleteDocument(String collection, String id) async {
    const allowedTables = {'parking_locations', 'parking_slots'};
    if (!allowedTables.contains(collection)) {
      throw ArgumentError.value(collection, 'collection', 'Unsupported table');
    }
    await _supabase.from(collection).delete().eq('id', id);
  }

  @override
  Future<void> seedDemoData() async {
    await _supabase.rpc('seed_demo_data');
  }
}
