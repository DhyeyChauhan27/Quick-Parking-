import 'package:flutter/material.dart';

abstract final class AppBreakpoints {
  static const phone = 700.0;
  static const customerRail = 900.0;
  static const desktop = 1200.0;
}

extension ResponsiveContext on BuildContext {
  double get layoutWidth => MediaQuery.sizeOf(this).width;

  bool get isPhoneLayout => layoutWidth < AppBreakpoints.phone;

  bool get isTabletLayout =>
      layoutWidth >= AppBreakpoints.phone &&
      layoutWidth < AppBreakpoints.desktop;

  bool get isDesktopLayout => layoutWidth >= AppBreakpoints.desktop;

  double get adaptivePagePadding {
    if (layoutWidth < 450) {
      return 12;
    }
    if (layoutWidth < AppBreakpoints.desktop) {
      return 16;
    }
    return 24;
  }
}
