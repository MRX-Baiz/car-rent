import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Permanent home for the pictures the user attaches: CIN and permis scans,
/// vehicle photos, the agency logo and signature.
///
/// The pickers do not give you a file you can keep. `image_picker` and
/// `file_picker` both hand back a copy in the app's *cache*, which Android
/// deletes whenever it wants the space; documents imported through the file
/// picker were additionally written to [Directory.systemTemp]. Saving those
/// paths straight into the database is why an attached permis was there when
/// you saved it and gone the next time the app opened — the row was fine, the
/// file underneath had been reclaimed.
///
/// So every attachment is copied here first, and only the file *name* is
/// stored. Names rather than full paths because the container directory is not
/// stable: iOS gives the app a new one on each update, so an absolute path
/// saved today stops resolving after the next release.
class MediaStore {
  MediaStore._();

  static final MediaStore instance = MediaStore._();

  static const String folderName = 'media';

  Directory? _directory;

  /// Must run before the first widget build, since [resolveSync] is called
  /// from build methods and cannot await anything.
  Future<void> init() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, folderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _directory = directory;
  }

  /// Test seam: point the store at a temporary directory.
  void debugSetDirectory(Directory directory) => _directory = directory;

  bool get isReady => _directory != null;

  /// Copies [source] into permanent storage and returns the name to persist.
  ///
  /// Throws [StateError] if [init] has not run — losing the picture silently is
  /// worse than a crash, which is the bug this class exists to fix.
  Future<String> save(File source, {required String prefix}) async {
    final directory = _directory;
    if (directory == null) {
      throw StateError('MediaStore.init() must run before saving attachments');
    }

    final extension = p.extension(source.path).replaceFirst('.', '');
    final suffix = extension.isEmpty ? '' : '.$extension';
    // Millisecond + random so two pictures attached in the same instant, or a
    // replacement of an existing one, cannot collide.
    final name = '${prefix}_${DateTime.now().millisecondsSinceEpoch}_'
        '${Random().nextInt(0xFFFF).toRadixString(16)}$suffix';

    await source.copy(p.join(directory.path, name));
    return name;
  }

  /// Absolute path for a stored value, or null when the file is missing.
  ///
  /// Callers show a placeholder on null rather than an image that fails to
  /// decode, so a file lost to the old bug degrades quietly.
  String? resolveSync(String? stored) {
    if (stored == null || stored.isEmpty) {
      return null;
    }

    // Rows written before this class existed hold an absolute cache path. Most
    // are dead by now, but honour the ones that survive.
    if (p.isAbsolute(stored)) {
      return File(stored).existsSync() ? stored : null;
    }

    final directory = _directory;
    if (directory == null) {
      return null;
    }
    final full = p.join(directory.path, stored);
    return File(full).existsSync() ? full : null;
  }

  File? resolveFile(String? stored) {
    final path = resolveSync(stored);
    return path == null ? null : File(path);
  }

  /// Removes an attachment that is no longer referenced. Never touches a
  /// legacy absolute path, which may live outside the app's storage.
  Future<void> delete(String? stored) async {
    if (stored == null || stored.isEmpty || p.isAbsolute(stored)) {
      return;
    }
    final directory = _directory;
    if (directory == null) {
      return;
    }
    final file = File(p.join(directory.path, stored));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
