import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/parking_repository.dart';

class AuthProvider extends ChangeNotifier {
  ParkingRepository? _repository;
  StreamSubscription<dynamic>? _authSubscription;

  bool _loading = true;
  bool _passwordRecovery = false;
  bool _showCustomerLoginAfterRecovery = false;
  AppUser? _profile;
  String? _error;

  bool get loading => _loading;
  bool get passwordRecovery => _passwordRecovery;
  bool get showCustomerLoginAfterRecovery => _showCustomerLoginAfterRecovery;
  AppUser? get profile => _profile;
  String? get error => _error;
  bool get isAuthenticated => _profile != null;
  bool get isAdmin => _profile?.isAdmin ?? false;

  void bind(ParkingRepository repository) {
    if (identical(_repository, repository)) {
      return;
    }
    _repository = repository;
    _authSubscription?.cancel();
    _authSubscription = repository.authStateChanges.listen(
      (event) {
        if (repository.isPasswordRecoveryEvent(event)) {
          _passwordRecovery = true;
          _loading = false;
          _error = null;
          notifyListeners();
          return;
        }
        _refreshProfile();
      },
      onError: (Object error, StackTrace stackTrace) {
        _error = error.toString();
        _loading = false;
        notifyListeners();
      },
    );
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    _loading = true;
    notifyListeners();

    try {
      _profile = await _repository?.getSignedInProfile();
      if (_profile != null) {
        _showCustomerLoginAfterRecovery = false;
      }
      _error = null;
    } catch (error) {
      _profile = null;
      _error = error.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> refreshProfile() => _refreshProfile();

  Future<void> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      await _repository!.registerCustomer(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      await _refreshProfile();
    } catch (error) {
      _error = error.toString();
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInCustomer({
    required String email,
    required String password,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      await _repository!.signInCustomer(email: email, password: password);
      await _refreshProfile();
    } catch (error) {
      _error = error.toString();
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      await _repository!.signInAdmin(email: email, password: password);
      await _refreshProfile();
    } catch (error) {
      _error = error.toString();
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _repository!.sendPasswordReset(email);
  }

  Future<void> updatePassword(String newPassword) async {
    await _repository!.updatePassword(newPassword);
  }

  Future<void> reauthenticate(String password) async {
    await _repository!.reauthenticate(password);
  }

  Future<void> finishPasswordRecovery() async {
    await _repository!.signOut();
    _passwordRecovery = false;
    _showCustomerLoginAfterRecovery = true;
    _profile = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  void leaveCustomerLoginAfterRecovery() {
    _showCustomerLoginAfterRecovery = false;
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    String? email,
    String? profileImageUrl,
  }) async {
    await _repository!.updateProfile(
      name: name,
      phone: phone,
      email: email,
      profileImageUrl: profileImageUrl,
    );
    await _refreshProfile();
  }

  Future<void> deleteProfileImage(String imageUrl) {
    return _repository!.deleteProfileImage(imageUrl);
  }

  Future<void> signOut() async {
    await _repository!.signOut();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
