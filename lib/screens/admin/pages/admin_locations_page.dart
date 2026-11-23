part of '../admin_shell.dart';

class _LocationsPage extends StatefulWidget {
  const _LocationsPage();

  @override
  State<_LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<_LocationsPage> {
  @override
  Widget build(BuildContext context) {
    final repo = context.read<ParkingRepository>();
    return StreamBuilder<List<ParkingLocation>>(
      stream: repo.parkingLocations(),
      builder: (context, snapshot) {
        final status = streamSnapshotStatus(
          snapshot,
          errorTitle: 'Could not load parking locations',
        );
        if (status != null) {
          return status;
        }
        final locations = snapshot.data ?? [];
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _showLocationDialog(context),
                icon: const Icon(Icons.add_business),
                label: const Text('Add Location'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: locations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final location = locations[index];
                  return ListTile(
                    tileColor: Theme.of(context).cardTheme.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    title: Text(location.name),
                    subtitle: Text(
                      '${location.address}, ${location.city}\n${location.availableSlots}/${location.totalSlots} available',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          onPressed: () =>
                              _showLocationDialog(context, location: location),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _runAdminAction(
                            context,
                            () => repo.deleteDocument(
                              'parking_locations',
                              location.id,
                            ),
                            successMessage: 'Parking location deleted.',
                          ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLocationDialog(
    BuildContext context, {
    ParkingLocation? location,
  }) async {
    final repo = context.read<ParkingRepository>();
    final name = TextEditingController(text: location?.name ?? '');
    final address = TextEditingController(text: location?.address ?? '');
    final city = TextEditingController(text: location?.city ?? '');
    final description = TextEditingController(
      text: location?.description ?? '',
    );
    final contact = TextEditingController(text: location?.contactNumber ?? '');
    final baseRate = TextEditingController(
      text: location?.baseRate.toString() ?? '30',
    );
    final totalSlots = TextEditingController(
      text: location?.totalSlots.toString() ?? '20',
    );
    final opening = TextEditingController(
      text: location?.openingHours ?? '24/7',
    );
    var imageUrl = location?.imageUrl ?? '';
    var uploading = false;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(location == null ? 'Add Location' : 'Edit Location'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        inputFormatters: [LengthLimitingTextInputFormatter(80)],
                        decoration: const InputDecoration(
                          labelText: 'Location Name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: address,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(180),
                        ],
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: city,
                        inputFormatters: [LengthLimitingTextInputFormatter(60)],
                        decoration: const InputDecoration(labelText: 'City'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: description,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(300),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contact,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Contact Number',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: baseRate,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Base Rate',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: totalSlots,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Total Slots',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: opening,
                        inputFormatters: [LengthLimitingTextInputFormatter(60)],
                        decoration: const InputDecoration(
                          labelText: 'Opening Hours',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _LocationImagePreview(source: imageUrl),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: uploading || saving
                            ? null
                            : () async {
                                setState(() => uploading = true);
                                try {
                                  final result = await FilePicker.platform
                                      .pickFiles(
                                        type: FileType.image,
                                        withData: true,
                                      );
                                  final file = result?.files.single;
                                  if (file == null) {
                                    return;
                                  }
                                  if (file.size > 5 * 1024 * 1024) {
                                    throw StateError(
                                      'Choose an image smaller than 5 MB.',
                                    );
                                  }
                                  final uploaded = await repo.uploadImage(
                                    file: file,
                                    folder: 'parking_locations',
                                  );
                                  if (dialogContext.mounted) {
                                    setState(() => imageUrl = uploaded);
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
                                  if (dialogContext.mounted) {
                                    setState(() => uploading = false);
                                  }
                                }
                              },
                        icon: uploading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(
                          uploading
                              ? 'Uploading...'
                              : imageUrl.isEmpty
                              ? 'Upload Location Image'
                              : 'Replace Image',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ResponsiveDialogActions(
                  children: [
                    TextButton(
                      onPressed: saving || uploading
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: saving || uploading
                          ? null
                          : () async {
                              final parsedRate = double.tryParse(
                                baseRate.text.trim(),
                              );
                              final parsedSlots = int.tryParse(
                                totalSlots.text.trim(),
                              );
                              if (name.text.trim().isEmpty ||
                                  address.text.trim().isEmpty ||
                                  city.text.trim().isEmpty ||
                                  opening.text.trim().isEmpty) {
                                showAppMessage(
                                  dialogContext,
                                  'Name, address, city, and opening hours are required.',
                                  error: true,
                                );
                                return;
                              }
                              if (name.text.trim().length < 2 ||
                                  city.text.trim().length < 2) {
                                showAppMessage(
                                  dialogContext,
                                  'Location name and city must contain at least 2 characters.',
                                  error: true,
                                );
                                return;
                              }
                              if (contact.text.isNotEmpty &&
                                  validatePhoneNumber(contact.text) != null) {
                                showAppMessage(
                                  dialogContext,
                                  'Enter a valid 10-digit contact number.',
                                  error: true,
                                );
                                return;
                              }
                              if (parsedRate == null || parsedRate < 0) {
                                showAppMessage(
                                  dialogContext,
                                  'Enter a valid base rate of 0 or more.',
                                  error: true,
                                );
                                return;
                              }
                              if (parsedRate > 100000 ||
                                  parsedSlots == null ||
                                  parsedSlots < 1 ||
                                  parsedSlots > 10000) {
                                showAppMessage(
                                  dialogContext,
                                  'Base rate must be below Rs 100000 and total slots must be between 1 and 10000.',
                                  error: true,
                                );
                                return;
                              }
                              setState(() => saving = true);
                              var savedSuccessfully = false;
                              try {
                                await repo.createOrUpdateLocation(
                                  locationId: location?.id,
                                  name: name.text.trim(),
                                  address: address.text.trim(),
                                  city: city.text.trim(),
                                  description: description.text.trim(),
                                  contactNumber: contact.text.trim(),
                                  baseRate: parsedRate,
                                  totalSlots: parsedSlots,
                                  openingHours: opening.text.trim(),
                                  imageUrl: imageUrl,
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
    // Keep controllers alive through the dialog exit animation.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    address.dispose();
    city.dispose();
    description.dispose();
    contact.dispose();
    baseRate.dispose();
    totalSlots.dispose();
    opening.dispose();
  }
}

class _LocationImagePreview extends StatelessWidget {
  const _LocationImagePreview({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    Widget errorBuilder(BuildContext context, Object error, StackTrace? stack) {
      return const SizedBox(
        height: 120,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      );
    }

    if (source.startsWith('data:image/')) {
      try {
        final separator = source.indexOf(',');
        if (separator < 0) {
          throw const FormatException('Invalid image data');
        }
        return Image.memory(
          base64Decode(source.substring(separator + 1)),
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: errorBuilder,
        );
      } on FormatException {
        return errorBuilder(
          context,
          const FormatException('Invalid image data'),
          null,
        );
      }
    }

    return Image.network(
      source,
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: errorBuilder,
    );
  }
}
