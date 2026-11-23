import 'package:flutter/material.dart';

class AdminConsoleProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  String _reportFilter = 'monthly';

  int get selectedIndex => _selectedIndex;
  String get reportFilter => _reportFilter;

  void selectIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void setReportFilter(String value) {
    _reportFilter = value;
    notifyListeners();
  }
}
