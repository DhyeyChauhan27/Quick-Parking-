import 'package:file_picker/file_picker.dart';

import '../models/app_models.dart';

abstract class ParkingRepository {
  Stream<Object?> get authStateChanges;

  bool isPasswordRecoveryEvent(Object? event);

  Future<AppUser?> getSignedInProfile();

  Future<void> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  });

  Future<void> signInCustomer({
    required String email,
    required String password,
  });

  Future<void> signInAdmin({required String email, required String password});

  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> reauthenticate(String password);
  Future<void> signOut();
  Stream<List<ParkingLocation>> parkingLocations({String query = ''});
  Stream<List<ParkingSlot>> slotsForLocation(String locationId);
  Stream<List<Booking>> bookingsForCustomer(String userId);
  Stream<List<Booking>> allBookings();
  Stream<List<AppUser>> allCustomers();
  Stream<List<PaymentRecord>> allPayments();
  Stream<List<AppNotification>> notificationsForCurrentUser();
  Stream<List<Complaint>> allComplaints();

  Future<double> calculatePrice({
    required ParkingLocation location,
    required ParkingSlot slot,
    required int durationHours,
  });

  Future<Booking> createBooking({
    required ParkingLocation location,
    required ParkingSlot slot,
    required DateTime startTime,
    required int durationHours,
    required String vehicleNumber,
  });

  Future<Booking> createBookingAndPay({
    required ParkingLocation location,
    required ParkingSlot slot,
    required DateTime startTime,
    required int durationHours,
    required String vehicleNumber,
    required String paymentMethod,
  });

  Future<void> recordDemoPayment({
    required Booking booking,
    String method = 'UPI',
  });

  Future<void> verifyBookingFlow(String codeOrPayload, {required bool checkIn});

  Future<void> updateProfile({
    required String name,
    required String phone,
    String? email,
    String? profileImageUrl,
  });

  Future<void> deleteProfileImage(String imageUrl);

  Future<void> markNotificationRead(String notificationId);

  Future<void> submitComplaint({
    required String subject,
    required String message,
  });

  Future<String> uploadImage({
    required PlatformFile file,
    required String folder,
  });

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
  });

  Future<void> createOrUpdateSlot({
    String? slotId,
    required String locationId,
    required String slotNumber,
    required String floor,
    required String type,
    required String status,
    required String vehicleType,
    required double ratePerHour,
  });

  Future<void> updateBookingStatus(String bookingId, String status);
  Future<void> deleteDocument(String collection, String id);
  Future<void> seedDemoData();
}
