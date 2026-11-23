import 'package:flutter/material.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({
    super.key,
    required this.onThemeChanged,
    required this.onLogout,
  });
  final VoidCallback onThemeChanged, onLogout;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: [
        const ListTile(
          leading: CircleAvatar(child: Text('AS')),
          title: Text('Ananya Singh'),
          subtitle: Text('Super admin'),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.currency_rupee),
          title: Text('Rates & discounts'),
          subtitle: Text('₹30/hr • 10% weekend discount'),
        ),
        const ListTile(
          leading: Icon(Icons.schedule),
          title: Text('Opening hours'),
          subtitle: Text('06:00 AM – 11:00 PM'),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('Appearance'),
          onTap: onThemeChanged,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          onTap: onLogout,
        ),
      ],
    ),
  );
}
