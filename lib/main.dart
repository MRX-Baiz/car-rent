import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/media_store.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for Windows/Linux desktop (required before any DB access).
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize local notifications early.
  await NotificationService.instance.initialize();

  // Attachments resolve synchronously during build, so the directory has to be
  // known before the first frame.
  await MediaStore.instance.init();

    runApp(
      const ProviderScope(
        child: CarRentApp(),
      ),
    );
  } catch (e, stack) {
    if (!kIsWeb) {
      try {
        File('crash_log.txt').writeAsStringSync('CRASH: $e\n\nSTACKTRACE:\n$stack');
      } catch (_) {}
    }
    rethrow;
  }
}

