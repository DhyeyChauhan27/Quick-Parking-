part of '../admin_shell.dart';

class _VerificationPage extends StatefulWidget {
  const _VerificationPage();

  @override
  State<_VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<_VerificationPage> {
  final _controller = TextEditingController();
  bool _verifying = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify(BuildContext context, bool checkIn) async {
    if (_verifying) {
      return;
    }
    final codeOrPayload = _controller.text.trim();
    if (codeOrPayload.isEmpty) {
      showAppMessage(
        context,
        'Enter a QR payload or booking code.',
        error: true,
      );
      return;
    }
    if (codeOrPayload.length > 1000) {
      showAppMessage(
        context,
        'The QR payload or booking code is too long.',
        error: true,
      );
      return;
    }
    setState(() => _verifying = true);
    try {
      await context.read<ParkingRepository>().verifyBookingFlow(
        codeOrPayload,
        checkIn: checkIn,
      );
      if (context.mounted) {
        showAppMessage(context, checkIn ? 'Entry verified.' : 'Exit verified.');
        _controller.clear();
      }
    } catch (error) {
      if (context.mounted) {
        showAppMessage(context, friendlyErrorMessage(error), error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'QR / Booking Verification',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Paste the QR payload or enter the booking code to validate vehicle entry and exit.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _controller,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'QR payload or booking code',
                    hintText: 'BOOKING ID:QP123456',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _verifying ? null : () => _verify(context, true),
                  icon: _verifying
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_verifying ? 'Verifying...' : 'Verify Entry'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _verifying ? null : () => _verify(context, false),
                  icon: const Icon(Icons.logout),
                  label: const Text('Verify Exit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
