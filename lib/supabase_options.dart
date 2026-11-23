import 'package:flutter/foundation.dart';

class SupabaseOptions {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://glqbsxaqdotctthqjmkq.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_x5qLywtG8FsvRcjla9Xhgg_tlvSVx0o',
  );

  static String get passwordResetRedirectUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return const String.fromEnvironment(
        'SUPABASE_MOBILE_REDIRECT_URL',
        defaultValue: 'com.quickparking.app://reset-password/',
      );
    }
    return const String.fromEnvironment(
      'PASSWORD_RESET_REDIRECT_URL',
      defaultValue: '',
    );
  }

  static bool get isConfigured =>
      url.startsWith('https://') &&
      url.contains('.supabase.co') &&
      !publishableKey.startsWith('YOUR-');
}
