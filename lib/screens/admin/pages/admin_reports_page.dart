part of '../admin_shell.dart';

class _ReportsPage extends StatefulWidget {
  const _ReportsPage();

  @override
  State<_ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<_ReportsPage> {
  bool _exporting = false;

  Future<ReportFileFormat?> _chooseFormat(String period) {
    final periodLabel = period == 'yearly' ? 'Yearly' : 'Monthly';
    return showDialog<ReportFileFormat>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose report format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF file'),
              subtitle: Text('Download the $periodLabel report as PDF'),
              onTap: () => Navigator.pop(dialogContext, ReportFileFormat.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('XML file'),
              subtitle: Text('Download the $periodLabel report as XML'),
              onTap: () => Navigator.pop(dialogContext, ReportFileFormat.xml),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReport({
    required String period,
    required List<Booking> bookings,
    required List<PaymentRecord> payments,
  }) async {
    final format = await _chooseFormat(period);
    if (format == null || !mounted) {
      return;
    }

    setState(() => _exporting = true);
    try {
      const exporter = ReportExportService();
      final generatedAt = DateTime.now();
      final bytes = switch (format) {
        ReportFileFormat.pdf => await exporter.buildPdf(
          period: period,
          generatedAt: generatedAt,
          bookings: bookings,
          payments: payments,
        ),
        ReportFileFormat.xml => exporter.buildXml(
          period: period,
          generatedAt: generatedAt,
          bookings: bookings,
          payments: payments,
        ),
      };
      final periodLabel = period == 'yearly' ? 'yearly' : 'monthly';
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save $periodLabel parking report',
        fileName: exporter.fileName(
          period: period,
          generatedAt: generatedAt,
          format: format,
        ),
        type: FileType.custom,
        allowedExtensions: [format.extension],
        bytes: bytes,
        lockParentWindow: true,
      );
      if (mounted && savedPath != null) {
        showAppMessage(
          context,
          '${format.label} report downloaded successfully.',
        );
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          'Could not download report. ${friendlyErrorMessage(error)}',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ParkingRepository>();
    final console = context.watch<AdminConsoleProvider>();
    return StreamBuilder<List<Booking>>(
      stream: repo.allBookings(),
      builder: (context, bookingsSnapshot) {
        return StreamBuilder<List<PaymentRecord>>(
          stream: repo.allPayments(),
          builder: (context, paymentsSnapshot) {
            final status =
                streamSnapshotStatus(
                  bookingsSnapshot,
                  errorTitle: 'Could not load report bookings',
                ) ??
                streamSnapshotStatus(
                  paymentsSnapshot,
                  errorTitle: 'Could not load report payments',
                );
            if (status != null) {
              return status;
            }
            final bookings = bookingsSnapshot.data ?? [];
            final payments = paymentsSnapshot.data ?? [];
            final now = DateTime.now();
            bool include(DateTime dateTime) {
              final localDateTime = dateTime.toLocal();
              switch (console.reportFilter) {
                case 'daily':
                  return localDateTime.year == now.year &&
                      localDateTime.month == now.month &&
                      localDateTime.day == now.day;
                case 'yearly':
                  return localDateTime.year == now.year;
                default:
                  return localDateTime.year == now.year &&
                      localDateTime.month == now.month;
              }
            }

            final filteredBookings = bookings
                .where((item) => include(item.startTime))
                .toList();
            final filteredPayments = payments
                .where(
                  (item) =>
                      item.status == 'success' &&
                      item.paidAt != null &&
                      include(item.paidAt!),
                )
                .toList();
            final revenue = filteredPayments.fold<double>(
              0,
              (sum, item) => sum + item.amount,
            );

            return ListView(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ChoiceChip(
                      label: const Text('Daily'),
                      selected: console.reportFilter == 'daily',
                      onSelected: (_) => console.setReportFilter('daily'),
                    ),
                    ChoiceChip(
                      label: const Text('Monthly'),
                      selected: console.reportFilter == 'monthly',
                      onSelected: (_) => console.setReportFilter('monthly'),
                    ),
                    ChoiceChip(
                      label: const Text('Yearly'),
                      selected: console.reportFilter == 'yearly',
                      onSelected: (_) => console.setReportFilter('yearly'),
                    ),
                  ],
                ),
                if (console.reportFilter != 'daily') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _exporting
                          ? null
                          : () => _downloadReport(
                              period: console.reportFilter,
                              bookings: filteredBookings,
                              payments: filteredPayments,
                            ),
                      icon: _exporting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(
                        _exporting
                            ? 'Preparing report...'
                            : 'Download ${console.reportFilter == 'yearly' ? 'Yearly' : 'Monthly'} Report',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report Summary',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text('Total bookings: ${filteredBookings.length}'),
                        Text('Total revenue: ${formatCurrency(revenue)}'),
                        Text(
                          'Occupancy activity: ${filteredBookings.where((item) => item.status == 'active' || item.status == 'completed').length} serviced bookings',
                        ),
                      ],
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
                          'Recent report rows',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ...filteredBookings
                            .take(10)
                            .map(
                              (booking) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${booking.bookingCode} - ${booking.locationName}',
                                ),
                                subtitle: Text(
                                  '${booking.slotNumber} - ${formatDateTime(booking.startTime)}',
                                ),
                                trailing: Text(formatCurrency(booking.amount)),
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
  }
}
