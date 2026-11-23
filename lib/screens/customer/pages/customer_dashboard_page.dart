part of '../customer_shell.dart';

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final customer = context.watch<AuthProvider>().profile!;
    final repo = context.read<ParkingRepository>();

    return AppShell(
      title: 'Customer Dashboard',
      actions: [
        IconButton(
          onPressed: () => context.read<AuthProvider>().signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${customer.name}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Search parking locations, review slot status, and confirm bookings with a QR pass.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () {
                    searchController.clear();
                  },
                  icon: const Icon(Icons.clear),
                ),
                labelText: 'Search by location, area, or city',
              ),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchController,
              builder: (context, value, _) {
                return StreamBuilder<List<ParkingLocation>>(
                  stream: repo.parkingLocations(query: value.text),
                  builder: (context, snapshot) {
                    final status = streamSnapshotStatus(
                      snapshot,
                      errorTitle: 'Could not load parking locations',
                    );
                    if (status != null) {
                      return status;
                    }
                    final locations = snapshot.data ?? [];
                    if (locations.isEmpty) {
                      return const EmptyState(
                        title: 'No locations found',
                        subtitle:
                            'Parking locations will appear after an administrator adds them.',
                        icon: Icons.location_off_outlined,
                      );
                    }
                    return ListView.separated(
                      primary: false,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: locations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final location = locations[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _LocationHeader(location: location),
                                const SizedBox(height: 14),
                                Text(location.description),
                                const SizedBox(height: 14),
                                StreamBuilder<List<ParkingSlot>>(
                                  stream: repo.slotsForLocation(location.id),
                                  builder: (context, slotSnapshot) {
                                    final status = streamSnapshotStatus(
                                      slotSnapshot,
                                      errorTitle:
                                          'Could not load parking slots',
                                    );
                                    if (status != null) {
                                      return status;
                                    }
                                    final slots = slotSnapshot.data ?? [];
                                    final freeCount = slots
                                        .where((slot) => slot.type == 'free')
                                        .length;
                                    final paidCount = slots
                                        .where((slot) => slot.type == 'paid')
                                        .length;
                                    final availableCount = slots
                                        .where(
                                          (slot) => slot.status == 'available',
                                        )
                                        .length;
                                    final occupiedCount = slots
                                        .where(
                                          (slot) => slot.status == 'occupied',
                                        )
                                        .length;
                                    final reservedCount = slots
                                        .where(
                                          (slot) => slot.status == 'reserved',
                                        )
                                        .length;

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            StatusChip('Free $freeCount'),
                                            StatusChip('Paid $paidCount'),
                                            StatusChip(
                                              'Available $availableCount',
                                            ),
                                            StatusChip(
                                              'Occupied $occupiedCount',
                                            ),
                                            StatusChip(
                                              'Reserved $reservedCount',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        Consumer<CustomerBookingProvider>(
                                          builder: (context, bookingState, child) {
                                            return Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: slots.map((slot) {
                                                final selected =
                                                    bookingState
                                                        .selectedSlot
                                                        ?.id ==
                                                    slot.id;
                                                return ChoiceChip(
                                                  label: Text(
                                                    '${slot.slotNumber} - ${slot.floor.replaceFirst(RegExp(r'\s+\d+$'), '')}',
                                                  ),
                                                  selected: selected,
                                                  // A checkmark changes the chip width and makes the
                                                  // surrounding slot grid jump when a slot is selected.
                                                  showCheckmark: false,
                                                  onSelected: slot.isAvailable
                                                      ? (_) {
                                                          bookingState
                                                              .selectLocation(
                                                                location,
                                                              );
                                                          bookingState
                                                              .selectSlot(slot);
                                                        }
                                                      : null,
                                                );
                                              }).toList(),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 18),
                                        _BookingPanel(location: location),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
  );
  }
}

class _BookingPanel extends StatefulWidget {
  const _BookingPanel({required this.location});

  final ParkingLocation location;

  @override
  State<_BookingPanel> createState() => _BookingPanelState();
}

class _BookingPanelState extends State<_BookingPanel> {
  final _bookingFormKey = GlobalKey<FormState>();
  late final TextEditingController _vehicleController;

  @override
  void initState() {
    super.initState();
    _vehicleController = TextEditingController(
      text: context.read<CustomerBookingProvider>().vehicleNumber,
    );
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<CustomerBookingProvider>();
    if (_vehicleController.text != booking.vehicleNumber) {
      _vehicleController.value = TextEditingValue(
        text: booking.vehicleNumber,
        selection: TextSelection.collapsed(
          offset: booking.vehicleNumber.length,
        ),
      );
    }
    if (booking.selectedLocation?.id != widget.location.id ||
        booking.selectedSlot == null) {
      return const Text('Select an available slot to continue booking.');
    }

    return Form(
      key: _bookingFormKey,
      child: Card(
        color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: LayoutBuilder(
          builder: (context, constraints) {
            final stackControls = constraints.maxWidth < 560;
            final controlWidth = stackControls ? constraints.maxWidth : 240.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book ${booking.selectedSlot!.slotNumber}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: controlWidth,
                      child: TextFormField(
                        controller: _vehicleController,
                        onChanged: booking.updateVehicleNumber,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(10),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            return newValue.copyWith(
                              text: newValue.text.toUpperCase(),
                              selection: newValue.selection,
                              composing: TextRange.empty,
                            );
                          }),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Number',
                          hintText: 'GJ01AB1234',
                          helperText: 'Exactly 10 letters and numbers',
                          counterText: '',
                        ),
                        maxLength: 10,
                        validator: (value) =>
                            RegExp(r'^[A-Z0-9]{10}$').hasMatch(
                              value?.trim().toUpperCase() ?? '',
                            )
                            ? null
                            : 'Enter exactly 10 letters and numbers',
                      ),
                    ),
                    SizedBox(
                      width: controlWidth,
                      child: DropdownButtonFormField<int>(
                        initialValue: booking.durationHours,
                        decoration: const InputDecoration(
                          labelText: 'Duration',
                        ),
                        menuMaxHeight: 220,
                        items: [1, 2, 3, 4, 5, 6]
                            .map(
                              (hour) => DropdownMenuItem(
                                value: hour,
                                child: Text('$hour hour${hour > 1 ? 's' : ''}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            booking.updateDuration(value);
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: stackControls ? controlWidth : null,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final selectedDate = await showDatePicker(
                            context: context,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 30)),
                            initialDate: booking.bookingDateTime,
                          );
                          if (!context.mounted || selectedDate == null) {
                            return;
                          }
                          final selectedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              booking.bookingDateTime,
                            ),
                          );
                          if (!context.mounted || selectedTime == null) {
                            return;
                          }
                          final selectedDateTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );
                          if (selectedDateTime.isBefore(DateTime.now())) {
                            showAppMessage(
                              context,
                              'Please select a future booking time.',
                              error: true,
                            );
                            return;
                          }
                          booking.updateBookingDate(selectedDateTime);
                        },
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          formatDateTime(booking.bookingDateTime),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Automatic price calculation: ${formatCurrency(booking.calculatedPrice)}',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: stackControls ? double.infinity : null,
                  child: ElevatedButton.icon(
                    onPressed: booking.processing
                        ? null
                        : () async {
                            if (!(_bookingFormKey.currentState?.validate() ??
                                false)) {
                              return;
                            }
                            try {
                              final confirmation = await showDialog<Booking>(
                                context: context,
                                barrierDismissible: false,
                                useRootNavigator: true,
                                builder: (_) =>
                                    _PaymentDialog(bookingState: booking),
                              );
                              if (!context.mounted || confirmation == null) {
                                return;
                              }
                              booking.reset();
                              _vehicleController.clear();
                            } catch (error) {
                              showAppMessage(
                                context,
                                friendlyErrorMessage(error),
                                error: true,
                              );
                            }
                          },
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(
                      booking.processing
                          ? 'Processing payment...'
                          : 'Continue to Payment',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  }
}

class _LocationHeader extends StatelessWidget {
  const _LocationHeader({required this.location});

  final ParkingLocation location;

  @override
  Widget build(BuildContext context) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text('${location.address}, ${location.city}'),
      ],
    );
    final availability = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusChip('${location.availableSlots} available'),
        const SizedBox(height: 6),
        Text('Base rate ${formatCurrency(location.baseRate)}/hr'),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [details, const SizedBox(height: 12), availability],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: details),
            const SizedBox(width: 20),
            availability,
          ],
        );
      },
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.bookingState});

  final CustomerBookingProvider bookingState;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  static const _upiId = String.fromEnvironment(
    'QUICKPARKING_UPI_ID',
    defaultValue: 'quickparking@upi',
  );

  late final Future<double> _amount;
  String _paymentMethod = 'UPI';
  bool _paying = false;
  bool _downloading = false;
  String? _error;
  Booking? _confirmation;

  @override
  void initState() {
    super.initState();
    _amount = widget.bookingState.calculateAmount();
  }

  Future<void> _pay() async {
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final booking = await widget.bookingState.createBookingAndPay(
        paymentMethod: _paymentMethod,
      );
      if (mounted) {
        setState(() {
          _confirmation = booking;
          _paying = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(error);
          _paying = false;
        });
      }
    }
  }

  String _upiPayload(double amount) {
    final reference =
        'QP${widget.bookingState.bookingDateTime.millisecondsSinceEpoch}';
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': _upiId,
        'pn': 'QuickParking',
        'tr': reference,
        'tn': 'Parking ${widget.bookingState.selectedSlot?.slotNumber ?? ''}',
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
      },
    ).toString();
  }

  String _escapeHtml(String value) {
    return const HtmlEscape().convert(value);
  }

  String _invoiceHtml(Booking booking) {
    final issuedAt = booking.createdAt ?? DateTime.now();
    return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>QuickParking Invoice ${_escapeHtml(booking.bookingCode)}</title>
  <style>
    body { margin: 0; background: #eef4f2; color: #152522; font-family: Arial, sans-serif; }
    .invoice { max-width: 760px; margin: 40px auto; background: white; border-radius: 20px; overflow: hidden; box-shadow: 0 14px 45px rgba(20, 62, 54, .14); }
    .header { padding: 30px 36px; background: #006b5f; color: white; }
    .header h1 { margin: 0 0 6px; font-size: 30px; }
    .header p { margin: 0; opacity: .85; }
    .content { padding: 32px 36px; }
    .paid { display: inline-block; padding: 8px 14px; border-radius: 999px; background: #d7f5eb; color: #006b5f; font-weight: 700; }
    table { width: 100%; margin-top: 24px; border-collapse: collapse; }
    td { padding: 12px 0; border-bottom: 1px solid #e5ecea; }
    td:last-child { text-align: right; font-weight: 700; }
    .total { margin-top: 26px; padding: 20px; border-radius: 14px; background: #e7f3f0; display: flex; justify-content: space-between; font-size: 22px; font-weight: 800; }
    .footer { padding: 20px 36px; background: #f7faf9; color: #58706b; text-align: center; }
    @media print { body { background: white; } .invoice { margin: 0; box-shadow: none; } }
  </style>
</head>
<body>
  <main class="invoice">
    <header class="header">
      <h1>QuickParking</h1>
      <p>Payment Invoice</p>
    </header>
    <section class="content">
      <span class="paid">PAID</span>
      <table>
        <tr><td>Invoice / Booking ID</td><td>${_escapeHtml(booking.bookingCode)}</td></tr>
        <tr><td>Issued On</td><td>${_escapeHtml(formatDateTime(issuedAt))}</td></tr>
        <tr><td>Parking Location</td><td>${_escapeHtml(booking.locationName)}</td></tr>
        <tr><td>Parking Slot</td><td>${_escapeHtml(booking.slotNumber)}</td></tr>
        <tr><td>Vehicle Number</td><td>${_escapeHtml(booking.vehicleNumber)}</td></tr>
        <tr><td>Parking Start</td><td>${_escapeHtml(formatDateTime(booking.startTime))}</td></tr>
        <tr><td>Parking End</td><td>${_escapeHtml(formatDateTime(booking.endTime))}</td></tr>
        <tr><td>Duration</td><td>${booking.durationHours} hour${booking.durationHours == 1 ? '' : 's'}</td></tr>
        <tr><td>Payment Method</td><td>${_escapeHtml(_paymentMethod)}</td></tr>
      </table>
      <div class="total"><span>Total Paid</span><span>${_escapeHtml(formatCurrency(booking.amount))}</span></div>
    </section>
    <footer class="footer">Thank you for choosing QuickParking.</footer>
  </main>
</body>
</html>''';
  }

  Future<void> _downloadInvoice(Booking booking) async {
    setState(() => _downloading = true);
    try {
      final invoiceBytes = Uint8List.fromList(
        utf8.encode(_invoiceHtml(booking)),
      );
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Download payment invoice',
        fileName: 'QuickParking-Invoice-${booking.bookingCode}.html',
        type: FileType.custom,
        allowedExtensions: const ['html'],
        bytes: invoiceBytes,
        lockParentWindow: true,
      );
      if (mounted && savedPath != null) {
        showAppMessage(context, 'Invoice downloaded successfully.');
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          'Could not download invoice. ${friendlyErrorMessage(error)}',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _confirmation;
    if (booking == null) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined),
            SizedBox(width: 10),
            Text('Payment'),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bookingState.selectedLocation?.name ?? '',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Slot ${widget.bookingState.selectedSlot?.slotNumber ?? ''}  |  Vehicle ${widget.bookingState.vehicleNumber}',
                ),
                Text(formatDateTime(widget.bookingState.bookingDateTime)),
                const SizedBox(height: 18),
                FutureBuilder<double>(
                  future: _amount,
                  builder: (context, snapshot) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Amount to pay: ${formatCurrency(snapshot.data ?? 0)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(
                      value: 'Pay at Parking',
                      child: Text('Pay at Parking'),
                    ),
                  ],
                  onChanged: _paying
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _paymentMethod = value);
                          }
                        },
                ),
                if (_paymentMethod == 'UPI') ...[
                  const SizedBox(height: 18),
                  FutureBuilder<double>(
                    future: _amount,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Center(
                        child: Column(
                          children: [
                            Text(
                              'Scan with any UPI app',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.white,
                              child: QrImageView(
                                data: _upiPayload(snapshot.data!),
                                size: 190,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text('UPI ID: $_upiId'),
                            const SizedBox(height: 4),
                            const Text(
                              'Complete payment on your phone, then tap I Have Paid.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ResponsiveDialogActions(
            children: [
              TextButton(
                onPressed: _paying ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _paying ? null : _pay,
                icon: _paying
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(
                  _paying
                      ? 'Processing...'
                      : _paymentMethod == 'UPI'
                      ? 'I Have Paid'
                      : 'Confirm Booking',
                ),
              ),
            ],
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle_outline),
          SizedBox(width: 10),
          Text('Payment Invoice'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Payment Successful',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 16),
              _InvoiceRow(label: 'Invoice ID', value: booking.bookingCode),
              _InvoiceRow(label: 'Location', value: booking.locationName),
              _InvoiceRow(label: 'Slot', value: booking.slotNumber),
              _InvoiceRow(label: 'Vehicle', value: booking.vehicleNumber),
              _InvoiceRow(label: 'Payment Method', value: _paymentMethod),
              _InvoiceRow(
                label: 'Amount Paid',
                value: formatCurrency(booking.amount),
              ),
              const SizedBox(height: 18),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Parking Verification QR',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    QrImageView(
                      data: booking.qrPayload,
                      size: 170,
                      backgroundColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ResponsiveDialogActions(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _downloading ? null : () => _downloadInvoice(booking),
              icon: _downloading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_downloading ? 'Downloading...' : 'Download Invoice'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, booking),
              child: const Text('Close'),
            ),
          ],
        ),
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
