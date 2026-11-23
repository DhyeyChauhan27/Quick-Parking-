part of '../admin_shell.dart';

class _PaymentsPage extends StatelessWidget {
  const _PaymentsPage();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ParkingRepository>();
    return StreamBuilder<List<Booking>>(
      stream: repo.allBookings(),
      builder: (context, bookingSnapshot) {
        final bookingMap = {
          for (final b in bookingSnapshot.data ?? []) b.id: b,
        };
        return StreamBuilder<List<PaymentRecord>>(
          stream: repo.allPayments(),
          builder: (context, snapshot) {
            final status = streamSnapshotStatus(
              snapshot,
              errorTitle: 'Could not load payments',
            );
            if (status != null) {
              return status;
            }
            final payments = snapshot.data ?? [];
            return payments.isEmpty
                ? const EmptyState(
                    title: 'No payments recorded',
                    subtitle:
                        'Payment receipts will appear here after customer bookings.',
                    icon: Icons.payments_outlined,
                  )
                : ListView.separated(
                    itemCount: payments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      final booking = bookingMap[payment.bookingId];
                      final placeDetail = booking != null
                          ? '${booking.locationName} · Slot ${booking.slotNumber}'
                          : payment.method;
                      return ListTile(
                        tileColor: Theme.of(context).cardTheme.color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        title: Text(formatCurrency(payment.amount)),
                        subtitle: Text('${payment.method} - $placeDetail'),
                        trailing: StatusChip(payment.status),
                      );
                    },
                  );
          },
        );
      },
    );
  }
}
