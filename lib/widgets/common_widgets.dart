import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../providers/theme_provider.dart';

String formatCurrency(double value) => 'Rs ${value.toStringAsFixed(0)}';

String formatDateTime(DateTime dateTime) {
  return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime.toLocal());
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  final valid = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  ).hasMatch(email);
  return valid ? null : 'Enter a valid email address';
}

String? validatePhoneNumber(String? value) {
  return RegExp(r'^\d{10}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Enter a valid 10-digit phone number';
}

String friendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is StateError) {
    return error.message.toString();
  }

  final raw = error.toString().trim();
  if (raw.isEmpty) {
    return fallback;
  }

  final lower = raw.toLowerCase();
  final isPausedSupabaseProject =
      lower.contains('project is paused') ||
      lower.contains('project paused') ||
      lower.contains('project_paused') ||
      lower.contains('statuscode: 540') ||
      lower.contains('status code: 540') ||
      lower.contains('code: 540') ||
      (lower.contains('failed host lookup') && lower.contains('.supabase.co'));
  if (isPausedSupabaseProject) {
    return 'QuickParking server is unavailable. Resume the paused Supabase '
        'project, wait a few minutes, then try again.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('failed host lookup')) {
    return 'Network connection failed. Check your internet and try again.';
  }
  if (lower.contains('timeoutexception')) {
    return 'The request timed out. Please try again.';
  }

  final structuredMessage = RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*(?:Exception|Error)\(message:\s*(.*?)(?:,\s*(?:code|statusCode):|\)$)',
    dotAll: true,
  ).firstMatch(raw);
  if (structuredMessage != null) {
    final message = structuredMessage.group(1)?.trim();
    return message == null || message.isEmpty ? fallback : message;
  }

  for (final prefix in const ['Bad state: ', 'Exception: ']) {
    if (raw.startsWith(prefix)) {
      final message = raw.substring(prefix.length).trim();
      return message.isEmpty ? fallback : message;
    }
  }

  final prefixedMessage = RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*(?:Exception|Error):\s*(.+)$',
    dotAll: true,
  ).firstMatch(raw);
  if (prefixedMessage != null) {
    final message = prefixedMessage.group(1)?.trim();
    return message == null || message.isEmpty ? fallback : message;
  }

  return raw;
}

void showAppMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.removeCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ),
  );
}

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl = '',
    this.radius = 24,
  });

  final String name;
  final String imageUrl;
  final double radius;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _imageFailed = false;

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _imageProvider(widget.imageUrl);
    final hasImage = image != null && !_imageFailed;
    final initial = widget.name.trim().isEmpty
        ? 'A'
        : widget.name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundImage: hasImage ? image : null,
      onForegroundImageError: hasImage
          ? (_, _) {
              if (mounted) {
                setState(() => _imageFailed = true);
              }
            }
          : null,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  ImageProvider<Object>? _imageProvider(String imageUrl) {
    final value = imageUrl.trim();
    if (value.isEmpty) {
      return null;
    }
    if (!value.startsWith('data:image/')) {
      return NetworkImage(value);
    }
    try {
      final separator = value.indexOf(',');
      if (separator < 0 || !value.substring(0, separator).contains(';base64')) {
        return null;
      }
      return MemoryImage(base64Decode(value.substring(separator + 1)));
    } catch (_) {
      return null;
    }
  }
}

Widget? streamSnapshotStatus<T>(
  AsyncSnapshot<T> snapshot, {
  String errorTitle = 'Unable to load data',
}) {
  if (snapshot.hasError) {
    return DataErrorState(
      title: errorTitle,
      message: friendlyErrorMessage(snapshot.error!),
    );
  }
  if (snapshot.connectionState == ConnectionState.waiting &&
      !snapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
  }
  return null;
}

class DataErrorState extends StatelessWidget {
  const DataErrorState({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: colors.error),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
    this.drawer,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.adaptivePagePadding),
          child: body,
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class ResponsiveDialogActions extends StatelessWidget {
  const ResponsiveDialogActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: children,
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: tint.withValues(alpha: 0.12),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class ThemeModeCard extends StatelessWidget {
  const ThemeModeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final selectedMode = themeProvider.themeMode == ThemeMode.system
        ? Theme.of(context).brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light
        : themeProvider.themeMode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selectedMode == ThemeMode.dark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                ),
                const SizedBox(width: 10),
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the display mode for the complete QuickParking app.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.light_mode_outlined, size: 18),
                  label: const Text('Light Mode'),
                  selected: selectedMode == ThemeMode.light,
                  onSelected: (_) =>
                      themeProvider.setThemeMode(ThemeMode.light),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.dark_mode_outlined, size: 18),
                  label: const Text('Dark Mode'),
                  selected: selectedMode == ThemeMode.dark,
                  onSelected: (_) => themeProvider.setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalized = label.toLowerCase();
    final color = switch (normalized) {
      'available' => Colors.green,
      'free' => Colors.teal,
      'reserved' => Colors.orange,
      'occupied' => Colors.red,
      'confirmed' => Colors.blue,
      'active' => Colors.indigo,
      'completed' => Colors.green,
      'paid' => Colors.green,
      _ => colors.secondary,
    };

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      visualDensity: VisualDensity.compact,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
