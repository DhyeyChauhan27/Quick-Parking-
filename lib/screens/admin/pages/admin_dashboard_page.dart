part of '../admin_shell.dart';

class _AdminDashboardPage extends StatelessWidget {
  const _AdminDashboardPage();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ParkingRepository>();
    return StreamBuilder<List<ParkingLocation>>(
      stream: repo.parkingLocations(),
      builder: (context, locationsSnapshot) {
        return StreamBuilder<List<Booking>>(
          stream: repo.allBookings(),
          builder: (context, bookingsSnapshot) {
            return StreamBuilder<List<PaymentRecord>>(
              stream: repo.allPayments(),
              builder: (context, paymentsSnapshot) {
                final status =
                    streamSnapshotStatus(
                      locationsSnapshot,
                      errorTitle: 'Could not load parking locations',
                    ) ??
                    streamSnapshotStatus(
                      bookingsSnapshot,
                      errorTitle: 'Could not load bookings',
                    ) ??
                    streamSnapshotStatus(
                      paymentsSnapshot,
                      errorTitle: 'Could not load payments',
                    );
                if (status != null) {
                  return status;
                }
                final locations = locationsSnapshot.data ?? [];
                final bookings = bookingsSnapshot.data ?? [];
                final payments = paymentsSnapshot.data ?? [];
                final totalSlots = locations.fold<int>(
                  0,
                  (sum, item) => sum + item.totalSlots,
                );
                final occupiedSlots = bookings
                    .where((booking) => booking.status == 'active')
                    .map((booking) => booking.slotId)
                    .toSet()
                    .length;
                final revenue = payments
                    .where((payment) => payment.status == 'success')
                    .fold<double>(0, (sum, item) => sum + item.amount);
                final dailyBookingCounts = List<double>.generate(
                  7,
                  (index) => bookings
                      .where(
                        (booking) => booking.startTime.weekday == index + 1,
                      )
                      .length
                      .toDouble(),
                );
                final highestDailyCount = dailyBookingCounts.fold<double>(
                  0,
                  (highest, count) => count > highest ? count : highest,
                );
                final chartMaxY = highestDailyCount < 4
                    ? 4.0
                    : highestDailyCount + 1;
                final colors = Theme.of(context).colorScheme;

                return ListView(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1000
                            ? 4
                            : constraints.maxWidth >= 560
                            ? 2
                            : 1;
                        final itemWidth =
                            (constraints.maxWidth - ((columns - 1) * 16)) /
                            columns;
                        final cards = [
                          SummaryCard(
                            title: 'Total Slots',
                            value: '$totalSlots',
                            icon: Icons.local_parking,
                            tint: Colors.teal,
                          ),
                          SummaryCard(
                            title: 'Occupied Slots',
                            value: '$occupiedSlots',
                            icon: Icons.car_rental,
                            tint: Colors.red,
                          ),
                          SummaryCard(
                            title: 'Revenue',
                            value: formatCurrency(revenue),
                            icon: Icons.account_balance_wallet,
                            tint: Colors.green,
                          ),
                          SummaryCard(
                            title: 'Bookings',
                            value: '${bookings.length}',
                            icon: Icons.event_available,
                            tint: Colors.indigo,
                          ),
                        ];
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: cards
                              .map(
                                (card) =>
                                    SizedBox(width: itemWidth, child: card),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          height: 330,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bookings by Day',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Number of parking bookings for each weekday',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: BarChart(
                                  BarChartData(
                                    minY: 0,
                                    maxY: chartMaxY,
                                    alignment: BarChartAlignment.spaceAround,
                                    borderData: FlBorderData(show: false),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: 1,
                                      getDrawingHorizontalLine: (value) =>
                                          FlLine(
                                            color: colors.outlineVariant
                                                .withValues(alpha: 0.35),
                                            strokeWidth: 1,
                                          ),
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 1,
                                          reservedSize: 44,
                                          getTitlesWidget: (value, meta) {
                                            if (value !=
                                                value.roundToDouble()) {
                                              return const SizedBox.shrink();
                                            }
                                            return SideTitleWidget(
                                              meta: meta,
                                              space: 10,
                                              child: Text(
                                                value.toInt().toString(),
                                                maxLines: 1,
                                                softWrap: false,
                                                style: TextStyle(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 1,
                                          reservedSize: 30,
                                          getTitlesWidget: (value, meta) {
                                            const labels = [
                                              'Mon',
                                              'Tue',
                                              'Wed',
                                              'Thu',
                                              'Fri',
                                              'Sat',
                                              'Sun',
                                            ];
                                            final index = value.toInt();
                                            if (value !=
                                                    value.roundToDouble() ||
                                                index < 0 ||
                                                index >= labels.length) {
                                              return const SizedBox.shrink();
                                            }
                                            return SideTitleWidget(
                                              meta: meta,
                                              space: 8,
                                              child: Text(
                                                labels[index],
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    barGroups: List.generate(7, (index) {
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: dailyBookingCounts[index],
                                            color: colors.primary,
                                            width: 18,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(6),
                                                  topRight: Radius.circular(6),
                                                ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily activity overview',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            ...bookings
                                .take(5)
                                .map(
                                  (booking) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${booking.bookingCode} - ${booking.locationName}',
                                    ),
                                    subtitle: Text(
                                      '${booking.slotNumber} - ${formatDateTime(booking.startTime)}',
                                    ),
                                    trailing: StatusChip(booking.status),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
