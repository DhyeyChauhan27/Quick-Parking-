part of '../admin_shell.dart';

class _BookingsPage extends StatelessWidget {
  const _BookingsPage();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ParkingRepository>();
    return StreamBuilder<List<Booking>>(
      stream: repo.allBookings(),
      builder: (context, snapshot) {
        final status = streamSnapshotStatus(
          snapshot,
          errorTitle: 'Could not load bookings',
        );
        if (status != null) {
          return status;
        }
        final bookings = snapshot.data ?? [];
        return bookings.isEmpty
            ? const EmptyState(
                title: 'No bookings available',
                subtitle:
                    'Customer reservations will appear here for management and verification.',
                icon: Icons.event_busy_outlined,
              )
            : ListView.separated(
                itemCount: bookings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  return ListTile(
                    tileColor: Theme.of(context).cardTheme.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    title: Text(
                      '${booking.bookingCode} - ${booking.locationName}',
                    ),
                    subtitle: Text(
                      '${booking.slotNumber} - ${booking.vehicleNumber}\n${formatDateTime(booking.startTime)}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        StatusChip(booking.status),
                        PopupMenuButton<String>(
                          onSelected: (value) => _runAdminAction(
                            context,
                            () => repo.updateBookingStatus(booking.id, value),
                            successMessage: 'Booking status updated.',
                          ),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'confirmed',
                              child: Text('Mark Confirmed'),
                            ),
                            PopupMenuItem(
                              value: 'active',
                              child: Text('Mark Active'),
                            ),
                            PopupMenuItem(
                              value: 'completed',
                              child: Text('Mark Completed'),
                            ),
                            PopupMenuItem(
                              value: 'cancelled',
                              child: Text('Mark Cancelled'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
      },
    );
  }
}
