import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/parking_repository.dart';

class CustomerBookingProvider extends ChangeNotifier {
  ParkingRepository? _repository;

  ParkingLocation? selectedLocation;
  ParkingSlot? selectedSlot;
  DateTime bookingDateTime = DateTime.now().add(const Duration(hours: 1));
  int durationHours = 2;
  String vehicleNumber = '';
  bool processing = false;

  /// Cached price — updated synchronously whenever slot/duration changes.
  double calculatedPrice = 0;

  void bind(ParkingRepository repository) {
    _repository = repository;
  }

  void _refreshPrice() {
    if (selectedLocation == null || selectedSlot == null || _repository == null) {
      calculatedPrice = 0;
      return;
    }
    final repo = _repository!;
    final loc = selectedLocation!;
    final slot = selectedSlot!;
    // calculatePrice is sync-equivalent (both demo and supabase use pure math)
    repo
        .calculatePrice(
          location: loc,
          slot: slot,
          durationHours: durationHours,
        )
        .then((price) {
          calculatedPrice = price;
          notifyListeners();
        });
  }

  void selectLocation(ParkingLocation location) {
    selectedLocation = location;
    selectedSlot = null;
    calculatedPrice = 0;
    notifyListeners();
  }

  void selectSlot(ParkingSlot slot) {
    selectedSlot = slot;
    _refreshPrice();
    notifyListeners();
  }

  void updateBookingDate(DateTime dateTime) {
    bookingDateTime = dateTime;
    notifyListeners();
  }

  void updateDuration(int hours) {
    durationHours = hours;
    _refreshPrice();
    // notifyListeners() is called inside _refreshPrice via .then()
  }

  void updateVehicleNumber(String value) {
    vehicleNumber = value.toUpperCase();
  }

  Future<double> calculateAmount() async {
    if (selectedLocation == null || selectedSlot == null) {
      return 0;
    }
    return _repository!.calculatePrice(
      location: selectedLocation!,
      slot: selectedSlot!,
      durationHours: durationHours,
    );
  }

  Future<Booking> createBookingAndPay({String paymentMethod = 'UPI'}) async {
    if (selectedLocation == null ||
        selectedSlot == null ||
        vehicleNumber.trim().isEmpty) {
      throw StateError('Please choose a location, slot, and vehicle number.');
    }
    if (!RegExp(r'^[A-Z0-9]{10}$').hasMatch(vehicleNumber.trim())) {
      throw StateError(
        'Vehicle number must contain exactly 10 letters and numbers, '
        'for example GJ01AB1234.',
      );
    }
    if (durationHours < 1 || durationHours > 24) {
      throw StateError('Duration must be between 1 and 24 hours.');
    }
    if (bookingDateTime.isBefore(
      DateTime.now().subtract(const Duration(minutes: 1)),
    )) {
      throw StateError('Please select a future booking date and time.');
    }
    if (!const {'UPI', 'Pay at Parking'}.contains(paymentMethod)) {
      throw StateError('Please select a valid payment method.');
    }
    processing = true;
    notifyListeners();
    try {
      final booking = await _repository!.createBookingAndPay(
        location: selectedLocation!,
        slot: selectedSlot!,
        startTime: bookingDateTime,
        durationHours: durationHours,
        vehicleNumber: vehicleNumber.trim(),
        paymentMethod: paymentMethod,
      );
      processing = false;
      notifyListeners();
      return booking;
    } catch (error) {
      processing = false;
      notifyListeners();
      rethrow;
    }
  }

  void reset() {
    selectedSlot = null;
    selectedLocation = null;
    vehicleNumber = '';
    calculatedPrice = 0;
    bookingDateTime = DateTime.now().add(const Duration(hours: 1));
    durationHours = 2;
    notifyListeners();
  }
}
