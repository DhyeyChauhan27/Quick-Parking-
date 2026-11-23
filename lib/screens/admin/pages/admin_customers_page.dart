part of '../admin_shell.dart';

class _CustomersPage extends StatelessWidget {
  const _CustomersPage();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ParkingRepository>();
    return StreamBuilder<List<AppUser>>(
      stream: repo.allCustomers(),
      builder: (context, snapshot) {
        final status = streamSnapshotStatus(
          snapshot,
          errorTitle: 'Could not load customers',
        );
        if (status != null) {
          return status;
        }
        final users = snapshot.data ?? [];
        return users.isEmpty
            ? const EmptyState(
                title: 'No customers',
                subtitle:
                    'Customer accounts created through registration will appear here.',
                icon: Icons.group_off_outlined,
              )
            : ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    tileColor: Theme.of(context).cardTheme.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    title: Text(user.name),
                    subtitle: Text('${user.email}\n${user.phone}'),
                    isThreeLine: true,
                    trailing: const StatusChip('customer'),
                  );
                },
              );
      },
    );
  }
}

