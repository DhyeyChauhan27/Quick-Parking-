import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../models/app_models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/parking_repository.dart';
import '../../services/report_export_service.dart';
import '../../widgets/common_widgets.dart';

part 'pages/admin_actions.dart';
part 'pages/admin_dashboard_page.dart';
part 'pages/admin_customers_page.dart';
part 'pages/admin_locations_page.dart';
part 'pages/admin_slots_page.dart';
part 'pages/admin_bookings_page.dart';
part 'pages/admin_payments_page.dart';
part 'pages/admin_verification_page.dart';
part 'pages/admin_reports_page.dart';
part 'pages/admin_settings_page.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  static const _titles = [
    'Dashboard',
    'Customers',
    'Locations',
    'Slots',
    'Bookings',
    'Payments',
    'QR Verification',
    'Reports',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final admin = auth.profile;
    if (admin == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text('Admin profile is unavailable'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: auth.loading ? null : auth.refreshProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final console = context.watch<AdminConsoleProvider>();
    final isPhone = context.isPhoneLayout;
    final isDesktop = context.isDesktopLayout;
    final pages = [
      const _AdminDashboardPage(),
      const _CustomersPage(),
      const _LocationsPage(),
      const _SlotsPage(),
      const _BookingsPage(),
      const _PaymentsPage(),
      const _VerificationPage(),
      const _ReportsPage(),
      const _SettingsPage(),
    ];

    final content = AppShell(
      title: _titles[console.selectedIndex],
      actions: [
        IconButton(
          onPressed: () => context.read<AuthProvider>().signOut(),
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
        ),
      ],
      drawer: isPhone
          ? NavigationDrawer(
              selectedIndex: console.selectedIndex,
              onDestinationSelected: (value) {
                console.selectIndex(value);
                Navigator.of(context).pop();
              },
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 20, 16),
                  child: Row(
                    children: [
                      ProfileAvatar(
                        name: admin.name,
                        imageUrl: admin.profileImageUrl,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              admin.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              admin.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ..._drawerDestinations,
              ],
            )
          : null,
      body: pages[console.selectedIndex],
    );

    if (isPhone) {
      return content;
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: console.selectedIndex,
              onDestinationSelected: console.selectIndex,
              extended: isDesktop,
              minWidth: 80,
              minExtendedWidth: 190,
              scrollable: true,
              groupAlignment: -1,
              labelType: isDesktop
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.selected,
              leading: Padding(
                padding: const EdgeInsets.all(12),
                child: ProfileAvatar(
                  radius: 24,
                  name: admin.name,
                  imageUrl: admin.profileImageUrl,
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.group_outlined),
                  selectedIcon: Icon(Icons.group),
                  label: Text('Customers'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.location_city_outlined),
                  selectedIcon: Icon(Icons.location_city),
                  label: Text('Locations'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.local_parking_outlined),
                  selectedIcon: Icon(Icons.local_parking),
                  label: Text('Slots'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.event_note_outlined),
                  selectedIcon: Icon(Icons.event_note),
                  label: Text('Bookings'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.payments_outlined),
                  selectedIcon: Icon(Icons.payments),
                  label: Text('Payments'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.qr_code_scanner_outlined),
                  selectedIcon: Icon(Icons.qr_code_scanner),
                  label: Text('Verify'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('Reports'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  static const _drawerDestinations = [
    NavigationDrawerDestination(
      icon: Icon(Icons.space_dashboard_outlined),
      selectedIcon: Icon(Icons.space_dashboard),
      label: Text('Dashboard'),
    ),
    NavigationDrawerDestination(
      icon: Icon(Icons.group_outlined),
      selectedIcon: Icon(Icons.group),
      label: Text('Customers'),
    ),
    NavigationDrawerDestination(
      icon: Icon(Icons.location_city_outlined),
      selectedIcon: Icon(Icons.location_city),
      label: Text('Locations'),
    ),
    NavigationDrawerDestination(
      icon: Icon(Icons.local_parking_outlined),
      selectedIcon: Icon(Icons.local_parking),
      label: Text('Slots'),
    ),
    NavigationDrawerDestination(
      icon: Icon(Icons.event_note_outlined),
      selectedIcon: Icon(Icons.event_note),
      label: Text('Bookings'),
    ),
    NavigationDrawerDestination(
      icon: Icon(Icons.payments_outlined),
      selectedIcon: Icon(Icons.payments),
      label: Text('Payments'),
    ),
    NavigationDrawerDestination(
      icon: Icon(Icons.qr_code_scanner_outlined),
      selectedIcon: Icon(Icons.qr_code_scanner),
      label: Text('Verify'),
    ),
    NavigationDrawerDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: Text('Reports'),
    ),
    NavigationDrawerDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('Settings'),
    ),
  ];
}
