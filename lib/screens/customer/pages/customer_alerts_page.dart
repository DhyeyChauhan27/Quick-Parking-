part of '../customer_shell.dart';

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ParkingRepository>();
    return AppShell(
      title: 'Notifications',
      body: StreamBuilder<List<AppNotification>>(
        stream: repo.notificationsForCurrentUser(),
        builder: (context, snapshot) {
          final status = streamSnapshotStatus(
            snapshot,
            errorTitle: 'Could not load notifications',
          );
          if (status != null) {
            return status;
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const EmptyState(
              title: 'No notifications',
              subtitle:
                  'Booking updates, payments, and admin verification alerts will appear here.',
              icon: Icons.notifications_off_outlined,
            );
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                tileColor: Theme.of(context).cardTheme.color,
                title: Text(item.title),
                subtitle: Text(item.message),
                trailing: item.read
                    ? const Icon(Icons.done_all)
                    : const Icon(Icons.fiber_new),
                onTap: item.read
                    ? null
                    : () async {
                        try {
                          await repo.markNotificationRead(item.id);
                        } catch (error) {
                          if (context.mounted) {
                            showAppMessage(
                              context,
                              friendlyErrorMessage(error),
                              error: true,
                            );
                          }
                        }
                      },
              );
            },
          );
        },
      ),
    );
  }
}

