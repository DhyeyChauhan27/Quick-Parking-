import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'supabase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var supabaseReady = false;
  String? bootstrapError;

  if (SupabaseOptions.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseOptions.url,
        publishableKey: SupabaseOptions.publishableKey,
        // Android recovery links can be opened after an app update or reinstall,
        // so they must not depend on a PKCE verifier stored by the old install.
        authOptions: FlutterAuthClientOptions(
          authFlowType:
              !kIsWeb && defaultTargetPlatform == TargetPlatform.android
              ? AuthFlowType.implicit
              : AuthFlowType.pkce,
        ),
      );
      supabaseReady = true;
    } catch (error) {
      bootstrapError = error.toString();
    }
  }

  runApp(
    QuickParkingApp(
      supabaseReady: supabaseReady,
      bootstrapError: bootstrapError,
    ),
  );
}
