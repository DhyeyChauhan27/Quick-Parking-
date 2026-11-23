part of '../admin_shell.dart';

class _SlotsPage extends StatefulWidget {
  const _SlotsPage();

  @override
  State<_SlotsPage> createState() => _SlotsPageState();
}

class _SlotsPageState extends State<_SlotsPage> {
  String? _selectedLocationId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ParkingRepository>();
    return StreamBuilder<List<ParkingLocation>>(
      stream: repo.parkingLocations(),
      builder: (context, locationsSnapshot) {
        final locationsStatus = streamSnapshotStatus(
          locationsSnapshot,
          errorTitle: 'Could not load parking locations',
        );
        if (locationsStatus != null) {
          return locationsStatus;
        }
        final locations = locationsSnapshot.data ?? [];
        _selectedLocationId ??= locations.isNotEmpty
            ? locations.first.id
            : null;
        ParkingLocation? selectedLocation;
        for (final location in locations) {
          if (location.id == _selectedLocationId) {
            selectedLocation = location;
            break;
          }
        }
        selectedLocation ??= locations.isNotEmpty ? locations.first : null;
        final activeLocation = selectedLocation;
        if (activeLocation == null) {
          return const EmptyState(
            title: 'No locations available',
            subtitle: 'Create a parking location first, then add slots for it.',
            icon: Icons.local_parking_outlined,
          );
        }
        return Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final selectorWidth = constraints.maxWidth < 560
                    ? constraints.maxWidth
                    : constraints.maxWidth - 166;
                final colors = Theme.of(context).colorScheme;
                final selector = DropdownMenu<String>(
                  key: ValueKey(activeLocation.id),
                  initialSelection: activeLocation.id,
                  expandedInsets: EdgeInsets.zero,
                  menuHeight: (locations.length * 56.0 + 16).clamp(72.0, 240.0),
                  label: const Text('Parking Location'),
                  leadingIcon: const Icon(Icons.location_on_outlined),
                  trailingIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                  selectedTrailingIcon: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                  ),
                  requestFocusOnTap: false,
                  selectOnly: true,
                  enableSearch: false,
                  alignmentOffset: const Offset(0, 8),
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  menuStyle: MenuStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      colors.surfaceContainerHigh,
                    ),
                    surfaceTintColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    elevation: const WidgetStatePropertyAll(10),
                    fixedSize: WidgetStatePropertyAll(
                      Size.fromWidth(selectorWidth),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 8),
                    ),
                    side: WidgetStatePropertyAll(
                      BorderSide(color: colors.outlineVariant),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  dropdownMenuEntries: locations.map((location) {
                    return DropdownMenuEntry(
                      value: location.id,
                      label: location.name,
                      style: MenuItemButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        textStyle: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  }).toList(),
                  onSelected: (value) {
                    if (value != null && value != _selectedLocationId) {
                      setState(() => _selectedLocationId = value);
                    }
                  },
                );
                final addButton = ElevatedButton.icon(
                  onPressed: () => _showSlotDialog(context, activeLocation),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Slot'),
                );

                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [selector, const SizedBox(height: 12), addButton],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: selector),
                    const SizedBox(width: 16),
                    SizedBox(width: 150, child: addButton),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<ParkingSlot>>(
                stream: repo.slotsForLocation(activeLocation.id),
                builder: (context, snapshot) {
                  final status = streamSnapshotStatus(
                    snapshot,
                    errorTitle: 'Could not load parking slots',
                  );
                  if (status != null) {
                    return status;
                  }
                  final slots = snapshot.data ?? [];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.maxWidth / 240)
                          .floor()
                          .clamp(1, 5);
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 240,
                        ),
                        itemCount: slots.length,
                        itemBuilder: (context, index) {
                          final slot = slots[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slot.slotNumber,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text('${slot.floor} - ${slot.vehicleType}'),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      StatusChip(slot.type),
                                      StatusChip(slot.status),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${formatCurrency(slot.ratePerHour)}/hr',
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _showSlotDialog(
                                          context,
                                          activeLocation,
                                          slot: slot,
                                        ),
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Edit slot',
                                        visualDensity: VisualDensity.compact,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                              width: 40,
                                              height: 40,
                                            ),
                                      ),
                                      IconButton(
                                        onPressed: () => _runAdminAction(
                                          context,
                                          () => repo.deleteDocument(
                                            'parking_slots',
                                            slot.id,
                                          ),
                                          successMessage:
                                              'Parking slot deleted.',
                                        ),
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Delete slot',
                                        visualDensity: VisualDensity.compact,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                              width: 40,
                                              height: 40,
                                            ),
                                      ),
                                    ],
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
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSlotDialog(
    BuildContext context,
    ParkingLocation location, {
    ParkingSlot? slot,
  }) async {
    final repo = context.read<ParkingRepository>();
    final slotNumber = TextEditingController(text: slot?.slotNumber ?? '');
    final floor = TextEditingController(text: slot?.floor ?? 'Ground');
    final rate = TextEditingController(
      text: slot?.ratePerHour.toString() ?? location.baseRate.toString(),
    );
    var type = slot?.type ?? 'paid';
    var status = slot?.status ?? 'available';
    var vehicleType = slot?.vehicleType ?? 'Car';
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(slot == null ? 'Add Slot' : 'Edit Slot'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: slotNumber,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Slot Number',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: floor,
                        inputFormatters: [LengthLimitingTextInputFormatter(40)],
                        decoration: const InputDecoration(labelText: 'Floor'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const ['free', 'paid']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => type = value ?? 'paid'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const ['available', 'occupied', 'reserved']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => status = value ?? 'available'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: vehicleType,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Type',
                        ),
                        items: const ['Car', 'Bike', 'EV']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => vehicleType = value ?? 'Car'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: rate,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Rate Per Hour',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ResponsiveDialogActions(
                  children: [
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final parsedRate = double.tryParse(
                                rate.text.trim(),
                              );
                              if (slotNumber.text.trim().isEmpty ||
                                  floor.text.trim().isEmpty) {
                                showAppMessage(
                                  dialogContext,
                                  'Slot number and floor are required.',
                                  error: true,
                                );
                                return;
                              }
                              if (slotNumber.text.trim().length < 2) {
                                showAppMessage(
                                  dialogContext,
                                  'Slot number must contain at least 2 characters.',
                                  error: true,
                                );
                                return;
                              }
                              if (parsedRate == null ||
                                  parsedRate < 0 ||
                                  parsedRate > 100000) {
                                showAppMessage(
                                  dialogContext,
                                  'Enter a valid hourly rate between Rs 0 and Rs 100000.',
                                  error: true,
                                );
                                return;
                              }
                              setState(() => saving = true);
                              var savedSuccessfully = false;
                              try {
                                await repo.createOrUpdateSlot(
                                  slotId: slot?.id,
                                  locationId: location.id,
                                  slotNumber: slotNumber.text.trim(),
                                  floor: floor.text.trim(),
                                  type: type,
                                  status: status,
                                  vehicleType: vehicleType,
                                  ratePerHour: parsedRate,
                                );
                                savedSuccessfully = true;
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              } catch (error) {
                                if (dialogContext.mounted) {
                                  showAppMessage(
                                    dialogContext,
                                    friendlyErrorMessage(error),
                                    error: true,
                                  );
                                }
                              } finally {
                                // Do not rebuild a dialog after its route begins closing.
                                if (!savedSuccessfully &&
                                    dialogContext.mounted) {
                                  setState(() => saving = false);
                                }
                              }
                            },
                      child: Text(saving ? 'Saving...' : 'Save'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    // A dialog route completes before its exit animation has fully removed its
    // text fields. Dispose their controllers only after that route is gone.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    slotNumber.dispose();
    floor.dispose();
    rate.dispose();
  }
}
