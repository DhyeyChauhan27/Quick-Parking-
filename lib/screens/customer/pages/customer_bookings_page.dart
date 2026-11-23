part of '../customer_shell.dart';

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ParkingRepository>();
    return AppShell(
      title: 'Booking History',
      body: StreamBuilder<List<Booking>>(
        stream: repo.bookingsForCustomer(userId),
        builder: (context, snapshot) {
          final status = streamSnapshotStatus(
            snapshot,
            errorTitle: 'Could not load your bookings',
          );
          if (status != null) {
            return status;
          }
          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return const EmptyState(
              title: 'No bookings yet',
              subtitle:
                  'Your confirmed and past parking reservations will appear here.',
              icon: Icons.receipt_long_outlined,
            );
          }
          return ListView.separated(
            itemCount: bookings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.locationName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Slot ${booking.slotNumber} - ${booking.bookingCode}',
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              StatusChip(booking.status),
                              StatusChip(booking.paymentStatus),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Start: ${formatDateTime(booking.startTime)}'),
                      Text('End: ${formatDateTime(booking.endTime)}'),
                      Text('Vehicle: ${booking.vehicleNumber}'),
                      Text('Amount: ${formatCurrency(booking.amount)}'),
                      if (booking.paymentStatus == 'paid') ...[
                        const SizedBox(height: 12),
                        QrImageView(
                          data: booking.qrPayload,
                          size: 140,
                          backgroundColor: Colors.white,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
