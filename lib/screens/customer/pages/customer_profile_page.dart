part of '../customer_shell.dart';

class _ProfilePage extends StatefulWidget {
  const _ProfilePage();

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  static const _maximumPhotoBytes = 2 * 1024 * 1024;
  final _profileKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  String? _selectedPhotoExtension;
  String _profileId = '';
  bool _removePhoto = false;
  bool _pickingPhoto = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _loadProfileIfNeeded(AppUser profile) {
    if (_profileId == profile.id) return;
    _profileId = profile.id;
    _name.text = profile.name;
    _phone.text = profile.phone;
  }

  String get _initial =>
      _name.text.trim().isEmpty ? 'C' : _name.text.trim()[0].toUpperCase();

  Future<void> _showPhotoActions(AppUser profile) async {
    final action = await showModalBottomSheet<_CustomerPhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () =>
                  Navigator.pop(sheetContext, _CustomerPhotoAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () =>
                  Navigator.pop(sheetContext, _CustomerPhotoAction.camera),
            ),
            if (profile.profileImageUrl.isNotEmpty ||
                _selectedPhotoBytes != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Remove Photo',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, _CustomerPhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _CustomerPhotoAction.remove) {
      setState(() {
        _selectedPhotoBytes = null;
        _selectedPhotoName = null;
        _selectedPhotoExtension = null;
        _removePhoto = true;
      });
      return;
    }
    await _pickPhoto(action);
  }

  Future<void> _pickPhoto(_CustomerPhotoAction action) async {
    if (action == _CustomerPhotoAction.camera) {
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (!status.isGranted) {
        _showPermissionMessage('Camera permission is needed to take a photo.');
        return;
      }
    }
    setState(() => _pickingPhoto = true);
    try {
      final file = await _picker.pickImage(
        source: action == _CustomerPhotoAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 512,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > _maximumPhotoBytes) {
        showAppMessage(
          context,
          'Choose a photo smaller than 2 MB.',
          error: true,
        );
        return;
      }
      final extension = _extensionFor(file);
      if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        showAppMessage(
          context,
          'Choose a JPG, PNG, or WebP image.',
          error: true,
        );
        return;
      }
      setState(() {
        _selectedPhotoBytes = bytes;
        _selectedPhotoName = file.name;
        _selectedPhotoExtension = extension;
        _removePhoto = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = friendlyErrorMessage(error);
      if (message.toLowerCase().contains('permission') ||
          message.toLowerCase().contains('denied')) {
        _showPermissionMessage('Photo permission was denied.');
      } else {
        showAppMessage(context, message, error: true);
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  String _extensionFor(XFile file) {
    final name = file.name.toLowerCase();
    final dot = name.lastIndexOf('.');
    return dot >= 0 && dot < name.length - 1 ? name.substring(dot + 1) : 'jpg';
  }

  void _showPermissionMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Open Settings',
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  Future<void> _saveProfile(AppUser profile) async {
    if (_saving || !(_profileKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    String? uploadedImageUrl;
    try {
      final repository = context.read<ParkingRepository>();
      final auth = context.read<AuthProvider>();
      if (_selectedPhotoBytes != null) {
        final originalName = _selectedPhotoName ?? 'profile.jpg';
        final fileName = originalName.contains('.')
            ? originalName
            : '$originalName.${_selectedPhotoExtension ?? 'jpg'}';
        final file = PlatformFile(
          name: fileName,
          size: _selectedPhotoBytes!.length,
          bytes: _selectedPhotoBytes,
        );
        uploadedImageUrl = await repository.uploadImage(
          file: file,
          folder: 'profile-images/${profile.id}',
        );
      }
      await auth.updateProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        profileImageUrl: uploadedImageUrl ?? (_removePhoto ? '' : null),
      );
      final oldImageUrl = profile.profileImageUrl;
      if ((uploadedImageUrl != null || _removePhoto) &&
          oldImageUrl.isNotEmpty &&
          oldImageUrl != uploadedImageUrl) {
        try {
          await auth.deleteProfileImage(oldImageUrl);
        } catch (_) {
          // The profile was saved; a later update can retry image cleanup.
        }
      }
      if (!mounted) return;
      setState(() {
        _selectedPhotoBytes = null;
        _selectedPhotoName = null;
        _selectedPhotoExtension = null;
        _removePhoto = false;
      });
      showAppMessage(context, 'Profile updated successfully');
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, friendlyErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset(AppUser profile) {
    setState(() {
      _name.text = profile.name;
      _phone.text = profile.phone;
      _selectedPhotoBytes = null;
      _selectedPhotoName = null;
      _selectedPhotoExtension = null;
      _removePhoto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    if (profile == null) {
      return const AppShell(
        title: 'Profile',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    _loadProfileIfNeeded(profile);
    final colors = Theme.of(context).colorScheme;
    final showingLocalPhoto = _selectedPhotoBytes != null;
    final imageUrl = _removePhoto ? '' : profile.profileImageUrl;
    return AppShell(
      title: 'Profile',
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _profileKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text('Update your personal profile details.'),
                      const SizedBox(height: 20),
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            showingLocalPhoto
                                ? CircleAvatar(
                                    radius: 46,
                                    backgroundColor: colors.primaryContainer,
                                    foregroundImage: MemoryImage(
                                      _selectedPhotoBytes!,
                                    ),
                                    child: Text(_initial),
                                  )
                                : ProfileAvatar(
                                    radius: 46,
                                    name: _name.text,
                                    imageUrl: imageUrl,
                                  ),
                            if (_pickingPhoto || _saving)
                              const Positioned.fill(
                                child: Center(
                                  child: SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: IconButton.filled(
                                onPressed: _saving || _pickingPhoto
                                    ? null
                                    : () => _showPhotoActions(profile),
                                tooltip: 'Change profile photo',
                                icon: const Icon(Icons.camera_alt_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 2
                            ? 'Enter at least 2 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: validatePhoneNumber,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: profile.email,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final saveButton = ElevatedButton(
                            onPressed: _saving
                                ? null
                                : () => _saveProfile(profile),
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save Profile'),
                          );
                          final resetButton = OutlinedButton(
                            onPressed: _saving ? null : () => _reset(profile),
                            child: const Text('Cancel / Reset'),
                          );
                          if (constraints.maxWidth < 440) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                saveButton,
                                const SizedBox(height: 10),
                                resetButton,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: saveButton),
                              const SizedBox(width: 12),
                              Expanded(child: resetButton),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const ThemeModeCard(),
          ],
        ),
      ),
    );
  }
}

enum _CustomerPhotoAction { gallery, camera, remove }
