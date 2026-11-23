part of '../admin_shell.dart';

Future<void> _runAdminAction(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  try {
    await action();
    if (context.mounted && successMessage != null) {
      showAppMessage(context, successMessage);
    }
  } catch (error) {
    if (context.mounted) {
      showAppMessage(context, friendlyErrorMessage(error), error: true);
    }
  }
}
