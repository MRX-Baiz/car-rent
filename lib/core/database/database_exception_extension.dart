import 'package:sqflite/sqflite.dart';

/// Extension to detect unique constraint violations across sqflite versions.
extension DatabaseExceptionExtension on DatabaseException {
  /// Returns true if this exception is due to a UNIQUE constraint failure.
  bool isUniqueConstraintError() {
    // SQLite error code for SQLITE_CONSTRAINT_UNIQUE is 2067.
    // Some versions expose result or only message.
    final msg = toString().toLowerCase();
    if (msg.contains('unique constraint') || msg.contains('unique_constraint')) {
      return true;
    }
    return false;
  }
}
