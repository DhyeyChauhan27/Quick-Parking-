import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quickparking_app/app.dart';
import 'package:quickparking_app/core/demo_credentials.dart';
import 'package:quickparking_app/models/app_models.dart';
import 'package:quickparking_app/providers/admin_provider.dart';
import 'package:quickparking_app/providers/auth_provider.dart';
import 'package:quickparking_app/providers/customer_provider.dart';
import 'package:quickparking_app/providers/theme_provider.dart';
import 'package:quickparking_app/screens/admin/admin_login_screen.dart';
import 'package:quickparking_app/screens/auth/auth_screens.dart';
import 'package:quickparking_app/screens/splash_gate.dart';
import 'package:quickparking_app/services/demo_parking_repository.dart';
import 'package:quickparking_app/services/report_export_service.dart';
import 'package:quickparking_app/widgets/common_widgets.dart';
import 'package:xml/xml.dart';

void main() {
  testWidgets('QuickParking starts in local demo mode', (tester) async {
    await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('QuickParking'), findsOneWidget);
  });

  testWidgets('Supabase startup failures do not silently use demo data', (
    tester,
  ) async {
    await tester.pumpWidget(
      const QuickParkingApp(
        supabaseReady: false,
        bootstrapError: 'SocketException: connection refused',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Database connection failed'), findsOneWidget);
    expect(find.text('Customer Dashboard'), findsNothing);
    expect(find.textContaining('Network connection failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash screen displays the correct product message', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('Smart parking management'), findsOneWidget);
    expect(find.text('Smart parking managementj'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome cards start below the app bar on phones', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(Card).first).dy, lessThan(100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer dashboard does not expose database seeding', (
    tester,
  ) async {
    await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Seed Demo'), findsNothing);
    expect(find.byTooltip('Seed demo parking data'), findsNothing);
  });

  testWidgets('customer layout adapts to phone tablet and laptop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    for (final size in const [
      Size(390, 844),
      Size(800, 1100),
      Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      if (size.width < 900) {
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      } else {
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Customer Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('all admin pages adapt to phone tablet and laptop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    for (final size in const [
      Size(390, 844),
      Size(800, 1100),
      Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      final appContext = tester.element(find.byType(MaterialApp));
      final auth = Provider.of<AuthProvider>(appContext, listen: false);
      await auth.signInAdmin(
        email: DemoCredentials.adminEmail,
        password: DemoCredentials.adminPassword,
      );
      await tester.pumpAndSettle();

      if (size.width < 700) {
        final hasDrawer = tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .any((scaffold) => scaffold.drawer is NavigationDrawer);
        expect(hasDrawer, isTrue);
        expect(find.byType(NavigationRail), findsNothing);
      } else {
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, size.width >= 1200);
      }
      expect(tester.takeException(), isNull);

      final console = Provider.of<AdminConsoleProvider>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      for (var index = 0; index < 9; index++) {
        console.selectIndex(index);
        await tester.pumpAndSettle();
        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: exception is FlutterError
              ? exception.toStringDeep()
              : 'Admin page $index overflowed at ${size.width}px',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('phone booking controls and payment dialog remain usable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    final locationList = find.byType(ListView).first;
    final slot = find.byType(ChoiceChip).first;
    await tester.drag(locationList, const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(slot);
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Phone booking panel overflowed after selecting a slot.',
    );

    final vehicleField = find.byType(TextFormField).first;
    await tester.enterText(vehicleField, 'GJ25AD1240');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final continueButton = find.ancestor(
      of: find.text('Continue to Payment'),
      matching: find.byType(ElevatedButton),
    );
    await tester.dragUntilVisible(
      continueButton,
      locationList,
      const Offset(0, -300),
    );
    // Leave clearance above the list viewport's clipped top edge.
    await tester.drag(locationList, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Phone booking controls overflowed after entering a vehicle.',
    );
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Scan with any UPI app'), findsOneWidget);
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: exception is FlutterError ? exception.toStringDeep() : null,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('phone admin location and slot dialogs remain usable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    final appContext = tester.element(find.byType(MaterialApp));
    final auth = Provider.of<AuthProvider>(appContext, listen: false);
    await auth.signInAdmin(
      email: DemoCredentials.adminEmail,
      password: DemoCredentials.adminPassword,
    );
    await tester.pumpAndSettle();

    final console = Provider.of<AdminConsoleProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    console.selectIndex(2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Location'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(
      find.text('Name, address, city, and opening hours are required.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    console.selectIndex(3);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Slot'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Slot number and floor are required.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('phone slot location menu stays anchored below its field', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    final appContext = tester.element(find.byType(MaterialApp));
    final auth = Provider.of<AuthProvider>(appContext, listen: false);
    await auth.signInAdmin(
      email: DemoCredentials.adminEmail,
      password: DemoCredentials.adminPassword,
    );
    await tester.pumpAndSettle();

    final console = Provider.of<AdminConsoleProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    console.selectIndex(3);
    await tester.pumpAndSettle();

    final selector = find.byType(DropdownMenu<String>);
    expect(selector, findsOneWidget);
    final fieldRect = tester.getRect(selector);

    await tester.tap(selector);
    await tester.pumpAndSettle();

    final secondLocation = find.widgetWithText(
      MenuItemButton,
      'Riverfront Mall Parking',
    );
    expect(secondLocation, findsOneWidget);
    final menuItemRect = tester.getRect(secondLocation);
    expect(menuItemRect.top, greaterThanOrEqualTo(fieldRect.bottom - 2));
    expect(menuItemRect.left, greaterThanOrEqualTo(fieldRect.left - 2));
    expect(menuItemRect.right, lessThanOrEqualTo(fieldRect.right + 2));
    expect(tester.takeException(), isNull);

    await tester.tap(secondLocation);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(MenuItemButton, 'Riverfront Mall Parking'),
      findsNothing,
    );
    expect(find.text('Riverfront Mall Parking'), findsOneWidget);
    expect(find.text('M1'), findsOneWidget);
    expect(find.text('A1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer and admin login fields start empty', (tester) async {
    Future<void> verifyEmptyLoginForm(Widget screen) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          child: MaterialApp(home: screen),
        ),
      );
      final fields = tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      );
      expect(fields, hasLength(2));
      for (final field in fields) {
        expect(field.controller?.text, isEmpty);
      }
      final editableFields = tester.widgetList<EditableText>(
        find.byType(EditableText),
      );
      expect(editableFields, hasLength(2));
      for (final field in editableFields) {
        expect(field.enableSuggestions, isFalse);
      }
    }

    await verifyEmptyLoginForm(const CustomerLoginScreen());
    await verifyEmptyLoginForm(const AdminLoginScreen());
  });

  testWidgets('password reset finishes on customer login with new password', (
    tester,
  ) async {
    await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    final auth = Provider.of<AuthProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    await auth.updatePassword('updated123');
    await auth.finishPasswordRecovery();
    await tester.pumpAndSettle();

    expect(find.text('Customer Login'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), DemoCredentials.customerEmail);
    await tester.enterText(fields.at(1), 'updated123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Customer Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin navigation and chart labels remain readable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1365, 680);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    final auth = Provider.of<AuthProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    await auth.signInAdmin(
      email: DemoCredentials.adminEmail,
      password: DemoCredentials.adminPassword,
    );
    await tester.pumpAndSettle();

    final navigationRail = tester.widget<NavigationRail>(
      find.byType(NavigationRail),
    );
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final leftTitles = chart.data.titlesData.leftTitles.sideTitles;

    expect(navigationRail.extended, isTrue);
    expect(navigationRail.scrollable, isTrue);
    expect(find.text('Settings'), findsOneWidget);
    expect(leftTitles.interval, 1);
    expect(leftTitles.reservedSize, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Slots'));
    await tester.pumpAndSettle();

    expect(find.text('Add Slot'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final adminConsole = Provider.of<AdminConsoleProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    adminConsole.selectIndex(8);
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Light Mode'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Parking Rates & Demo Data'), findsNothing);
    expect(find.text('Seed Demo Dataset'), findsNothing);
    expect(find.text('Complaints'), findsNothing);
  });

  testWidgets('monthly and yearly reports ask for PDF or XML format', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    final auth = Provider.of<AuthProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    await auth.signInAdmin(
      email: DemoCredentials.adminEmail,
      password: DemoCredentials.adminPassword,
    );
    final console = Provider.of<AdminConsoleProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    console.selectIndex(7);
    await tester.pumpAndSettle();

    expect(find.text('Download Monthly Report'), findsOneWidget);
    await tester.tap(find.text('Download Monthly Report'));
    await tester.pumpAndSettle();
    expect(find.text('Choose report format'), findsOneWidget);
    expect(find.text('PDF file'), findsOneWidget);
    expect(find.text('XML file'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(find.text('Download Yearly Report'), findsOneWidget);
    await tester.tap(find.text('Download Yearly Report'));
    await tester.pumpAndSettle();
    expect(find.text('Choose report format'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verification requires a booking code before checking in', (
    tester,
  ) async {
    await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    final auth = Provider.of<AuthProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    await auth.signInAdmin(
      email: DemoCredentials.adminEmail,
      password: DemoCredentials.adminPassword,
    );
    final console = Provider.of<AdminConsoleProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    console.selectIndex(6);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verify Entry'));
    await tester.pump();

    expect(find.text('Enter a QR payload or booking code.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer profile switches between light and dark mode', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    final themeProvider = Provider.of<ThemeProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Light Mode'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Complaint / Support'), findsNothing);
    expect(find.text('Send Complaint'), findsNothing);

    await tester.tap(find.text('Light Mode'));
    await tester.pumpAndSettle();
    expect(themeProvider.themeMode, ThemeMode.light);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );

    await tester.tap(find.text('Dark Mode'));
    await tester.pumpAndSettle();
    expect(themeProvider.themeMode, ThemeMode.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(tester.takeException(), isNull);
  });

  test('vehicle typing updates value without rebuilding the dashboard', () {
    final provider = CustomerBookingProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);

    provider.updateVehicleNumber('gj01ab1234');

    expect(provider.vehicleNumber, 'GJ01AB1234');
    expect(notifications, 0);
  });

  test('local demo login validates the Gmail credentials', () async {
    final repository = DemoParkingRepository();

    await repository.signOut();
    await repository.signInCustomer(
      email: DemoCredentials.customerEmail,
      password: DemoCredentials.customerPassword,
    );
    expect(
      (await repository.getSignedInProfile())?.email,
      DemoCredentials.customerEmail,
    );

    await repository.signOut();
    await expectLater(
      repository.signInCustomer(
        email: DemoCredentials.customerEmail,
        password: 'wrong-password',
      ),
      throwsA(isA<StateError>()),
    );

    await repository.signInAdmin(
      email: DemoCredentials.adminEmail,
      password: DemoCredentials.adminPassword,
    );
    expect(
      (await repository.getSignedInProfile())?.email,
      DemoCredentials.adminEmail,
    );
  });

  testWidgets('vehicle number stays visible after duration changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const QuickParkingApp(supabaseReady: false));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pumpAndSettle();

    final vehicleField = find.byType(TextFormField).first;
    await tester.enterText(vehicleField, 'gj25ad1240');
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 hours').last);
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(vehicleField);
    expect(field.controller?.text, 'GJ25AD1240');
  });

  test(
    'payment rejects a vehicle number that is not exactly 10 characters',
    () async {
      final repository = DemoParkingRepository();
      final provider = CustomerBookingProvider()..bind(repository);
      final location = (await repository.parkingLocations().first).first;
      final slot = (await repository.slotsForLocation(location.id).first).first;

      provider.selectLocation(location);
      provider.selectSlot(slot);
      provider.updateVehicleNumber('GJ01AB123');

      await expectLater(
        provider.createBookingAndPay(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('exactly 10'),
          ),
        ),
      );
    },
  );

  test(
    'payment step records the selected method and confirms booking',
    () async {
      final repository = DemoParkingRepository();
      final provider = CustomerBookingProvider()..bind(repository);
      final location = (await repository.parkingLocations().first).first;
      final slot = (await repository.slotsForLocation(location.id).first).first;

      provider.selectLocation(location);
      provider.selectSlot(slot);
      provider.updateVehicleNumber('GJ01AB1234');
      final booking = await provider.createBookingAndPay(paymentMethod: 'UPI');
      final payments = await repository.allPayments().first;

      expect(booking.bookingCode, startsWith('QP'));
      expect(booking.status, 'confirmed');
      expect(booking.paymentStatus, 'paid');
      expect(payments.single.method, 'UPI');
    },
  );

  test('report exporter creates valid PDF and XML files', () async {
    const exporter = ReportExportService();
    final generatedAt = DateTime(2026, 9, 4, 16, 30);
    final booking = Booking(
      id: 'booking-1',
      bookingCode: 'QP12345678',
      userId: 'user-1',
      locationId: 'location-1',
      locationName: 'City & Mall Parking',
      slotId: 'slot-1',
      slotNumber: 'A1',
      startTime: generatedAt,
      endTime: generatedAt.add(const Duration(hours: 2)),
      durationHours: 2,
      status: 'completed',
      amount: 90,
      paymentStatus: 'paid',
      qrPayload: 'BOOKING:QP12345678',
      vehicleNumber: 'GJ01AB1234',
    );
    final payment = PaymentRecord(
      id: 'payment-1',
      bookingId: booking.id,
      userId: booking.userId,
      amount: booking.amount,
      method: 'UPI',
      status: 'success',
      paidAt: generatedAt,
    );

    final pdf = await exporter.buildPdf(
      period: 'monthly',
      generatedAt: generatedAt,
      bookings: [booking],
      payments: [payment],
    );
    final xmlBytes = exporter.buildXml(
      period: 'yearly',
      generatedAt: generatedAt,
      bookings: [booking],
      payments: [payment],
    );
    final xml = XmlDocument.parse(utf8.decode(xmlBytes));

    expect(ascii.decode(pdf.sublist(0, 4)), '%PDF');
    expect(xml.rootElement.name.local, 'quickParkingReport');
    expect(xml.rootElement.getAttribute('period'), 'yearly');
    expect(
      xml.findAllElements('location').single.innerText,
      'City & Mall Parking',
    );
    expect(xml.findAllElements('totalRevenue').single.innerText, '90.0');
    expect(
      exporter.fileName(
        period: 'monthly',
        generatedAt: generatedAt,
        format: ReportFileFormat.pdf,
      ),
      'QuickParking-Monthly-2026-09.pdf',
    );
  });

  test('technical exceptions are converted to user-friendly messages', () {
    const raw =
        'PostgrestException(message: Only a paid, confirmed booking can be checked in., code: P0001, details: , hint: null)';

    expect(
      friendlyErrorMessage(raw),
      'Only a paid, confirmed booking can be checked in.',
    );
    expect(
      friendlyErrorMessage(StateError('Booking code not found.')),
      'Booking code not found.',
    );
    expect(
      friendlyErrorMessage(
        const FormatException('The supplied booking code is invalid.'),
      ),
      'The supplied booking code is invalid.',
    );
    expect(
      friendlyErrorMessage(
        "ClientException with SocketException: Failed host lookup: "
        "'glqbsxaqdotctthqjmkq.supabase.co'",
      ),
      'QuickParking server is unavailable. Resume the paused Supabase '
      'project, wait a few minutes, then try again.',
    );
    expect(
      friendlyErrorMessage(
        'PostgrestException(message: Project is paused, code: 540, '
        'details: null, hint: null)',
      ),
      'QuickParking server is unavailable. Resume the paused Supabase '
      'project, wait a few minutes, then try again.',
    );
  });

  test('email and phone validators reject malformed account details', () {
    expect(validateEmail('customer@gmail.com'), isNull);
    expect(validateEmail('customer@gmail'), isNotNull);
    expect(validateEmail('customer gmail.com'), isNotNull);
    expect(validatePhoneNumber('9876543210'), isNull);
    expect(validatePhoneNumber('98765abcde'), isNotNull);
  });

  test('database timestamps are converted to device local time', () {
    final parsed = dateTimeFromDynamic('2026-09-02T06:30:00.000Z');

    expect(parsed, DateTime.utc(2026, 9, 2, 6, 30).toLocal());
    expect(parsed?.isUtc, isFalse);
  });

  test('booking rejects a past date before changing slot state', () async {
    final repository = DemoParkingRepository();
    final provider = CustomerBookingProvider()..bind(repository);
    final location = (await repository.parkingLocations().first).first;
    final slot = (await repository.slotsForLocation(location.id).first).first;

    provider.selectLocation(location);
    provider.selectSlot(slot);
    provider.updateVehicleNumber('GJ01AB1234');
    provider.updateBookingDate(
      DateTime.now().subtract(const Duration(hours: 2)),
    );

    await expectLater(
      provider.createBookingAndPay(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('future booking'),
        ),
      ),
    );
    expect(
      (await repository.slotsForLocation(location.id).first).first.status,
      'available',
    );
  });

  test('completing a booking releases its slot exactly once', () async {
    final repository = DemoParkingRepository();
    final provider = CustomerBookingProvider()..bind(repository);
    final location = (await repository.parkingLocations().first).first;
    final slot = (await repository.slotsForLocation(location.id).first).first;

    provider.selectLocation(location);
    provider.selectSlot(slot);
    provider.updateVehicleNumber('GJ01AB1234');
    final booking = await provider.createBookingAndPay();

    await repository.updateBookingStatus(booking.id, 'active');
    await repository.updateBookingStatus(booking.id, 'completed');

    final updatedSlot = (await repository.slotsForLocation(location.id).first)
        .firstWhere((item) => item.id == slot.id);
    final updatedLocation = (await repository.parkingLocations().first)
        .firstWhere((item) => item.id == location.id);
    expect(updatedSlot.status, 'available');
    expect(updatedSlot.currentBookingId, isEmpty);
    expect(updatedLocation.availableSlots, location.availableSlots);
    await expectLater(
      repository.updateBookingStatus(booking.id, 'confirmed'),
      throwsA(isA<StateError>()),
    );
  });

  test('QR verification rejects duplicate vehicle entry', () async {
    final repository = DemoParkingRepository();
    final provider = CustomerBookingProvider()..bind(repository);
    final location = (await repository.parkingLocations().first).first;
    final slot = (await repository.slotsForLocation(location.id).first).first;

    provider.selectLocation(location);
    provider.selectSlot(slot);
    provider.updateVehicleNumber('GJ01AB1234');
    final booking = await provider.createBookingAndPay();
    await repository.verifyBookingFlow(booking.bookingCode, checkIn: true);

    await expectLater(
      repository.verifyBookingFlow(booking.bookingCode, checkIn: true),
      throwsA(isA<StateError>()),
    );
  });
}
