part of '../admin_shell.dart';

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    if (profile == null) {
      if (auth.loading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Admin profile is unavailable',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              friendlyErrorMessage(
                StateError(auth.error ?? 'Please check your connection.'),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.read<AuthProvider>().refreshProfile(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          _EditAccountCard(profile: profile),
          const SizedBox(height: 16),
          const ThemeModeCard(),
        ],
      ),
    );
  }
}

class _EditAccountCard extends StatefulWidget {
  const _EditAccountCard({required this.profile});
  final AppUser profile;

  @override
  State<_EditAccountCard> createState() => _EditAccountCardState();
}

class _EditAccountCardState extends State<_EditAccountCard> {
  static const _maximumPhotoBytes = 2 * 1024 * 1024;
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  String? _selectedPhotoExtension;
  String _profileId = '';
  bool _removePhoto = false;
  bool _pickingPhoto = false;
  bool _saving = false;
  bool _changePasswordExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadProfileIfNeeded(widget.profile);
  }

  @override
  void didUpdateWidget(covariant _EditAccountCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _loadProfileIfNeeded(widget.profile);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _loadProfileIfNeeded(AppUser profile) {
    if (_profileId == profile.id) return;
    _profileId = profile.id;
    _nameController.text = profile.name;
    _emailController.text = profile.email;
    _phoneController.text = profile.phone;
  }

  String get _initial => _nameController.text.trim().isEmpty
      ? 'A'
      : _nameController.text.trim()[0].toUpperCase();

  Future<void> _showPhotoActions() async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(sheetContext, _PhotoAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(sheetContext, _PhotoAction.camera),
            ),
            if (widget.profile.profileImageUrl.isNotEmpty ||
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
                onTap: () => Navigator.pop(sheetContext, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _PhotoAction.remove) {
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

  Future<void> _pickPhoto(_PhotoAction action) async {
    if (action == _PhotoAction.camera) {
      final cameraStatus = await Permission.camera.request();
      if (!mounted) return;
      if (!cameraStatus.isGranted) {
        _showPermissionMessage('Camera permission is needed to take a photo.');
        return;
      }
    }
    setState(() => _pickingPhoto = true);
    try {
      final file = await _picker.pickImage(
        source: action == _PhotoAction.camera
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

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();
    final emailChanged = email != widget.profile.email.trim().toLowerCase();
    final newPassword = _newPasswordController.text;
    final changingPassword = newPassword.isNotEmpty;
    if ((emailChanged || changingPassword) &&
        _currentPasswordController.text.isEmpty) {
      setState(() => _changePasswordExpanded = true);
      showAppMessage(
        context,
        'Enter your current password before changing email or password.',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    String? uploadedImageUrl;
    try {
      final auth = context.read<AuthProvider>();
      final repository = context.read<ParkingRepository>();
      if (emailChanged || changingPassword) {
        await auth.reauthenticate(_currentPasswordController.text);
      }
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
          folder: 'profile-images/${widget.profile.id}',
        );
      }
      await auth.updateProfile(
        name: name,
        phone: phone,
        email: email,
        profileImageUrl: uploadedImageUrl ?? (_removePhoto ? '' : null),
      );
      if (changingPassword) {
        await auth.updatePassword(newPassword);
      }
      final oldImageUrl = widget.profile.profileImageUrl;
      if ((uploadedImageUrl != null || _removePhoto) &&
          oldImageUrl.isNotEmpty &&
          oldImageUrl != uploadedImageUrl) {
        try {
          await auth.deleteProfileImage(oldImageUrl);
        } catch (_) {
          // The new profile is already saved; a later update can retry cleanup.
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedPhotoBytes = null;
        _selectedPhotoName = null;
        _selectedPhotoExtension = null;
        _removePhoto = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
      showAppMessage(context, 'Profile updated successfully');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppMessage(context, friendlyErrorMessage(error), error: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _reset() {
    setState(() {
      _nameController.text = widget.profile.name;
      _emailController.text = widget.profile.email;
      _phoneController.text = widget.profile.phone;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _selectedPhotoBytes = null;
      _selectedPhotoName = null;
      _selectedPhotoExtension = null;
      _removePhoto = false;
      _changePasswordExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showingLocalPhoto = _selectedPhotoBytes != null;
    final imageUrl = _removePhoto ? '' : widget.profile.profileImageUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, color: colors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Update your admin profile details.'),
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    showingLocalPhoto
                        ? CircleAvatar(
                            radius: 46,
                            backgroundColor: colors.primaryContainer,
                            foregroundImage: MemoryImage(_selectedPhotoBytes!),
                            child: Text(_initial),
                          )
                        : ProfileAvatar(
                            radius: 46,
                            name: _nameController.text,
                            imageUrl: imageUrl,
                          ),
                    if (_pickingPhoto || _saving)
                      const Positioned.fill(
                        child: Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ),
                      ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: IconButton.filled(
                        onPressed: _saving || _pickingPhoto
                            ? null
                            : _showPhotoActions,
                        tooltip: 'Change profile photo',
                        icon: const Icon(Icons.camera_alt_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
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
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone Number (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) => (value?.trim() ?? '').isEmpty
                    ? null
                    : validatePhoneNumber(value),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Change Password'),
                subtitle: const Text(
                  'Optional. Required for email changes too.',
                ),
                leading: const Icon(Icons.lock_outline),
                initiallyExpanded: _changePasswordExpanded,
                onExpansionChanged: (value) =>
                    setState(() => _changePasswordExpanded = value),
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                    ),
                    validator: (value) {
                      final needsCurrent =
                          _emailController.text.trim().toLowerCase() !=
                              widget.profile.email.trim().toLowerCase() ||
                          _newPasswordController.text.isNotEmpty ||
                          _confirmPasswordController.text.isNotEmpty;
                      return needsCurrent && (value?.isEmpty ?? true)
                          ? 'Enter your current password'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                    ),
                    validator: (value) {
                      if ((value?.isEmpty ?? true) &&
                          _confirmPasswordController.text.isEmpty) {
                        return null;
                      }
                      return (value?.length ?? 0) < 6
                          ? 'Password must be at least 6 characters'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                    ),
                    validator: (value) {
                      if (_newPasswordController.text.isEmpty &&
                          (value?.isEmpty ?? true)) {
                        return null;
                      }
                      return value == _newPasswordController.text
                          ? null
                          : 'New passwords do not match';
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final saveButton = ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  );
                  final resetButton = OutlinedButton(
                    onPressed: _saving ? null : _reset,
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
    );
  }
}

enum _PhotoAction { gallery, camera, remove }
