import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Central SQLite access point for the CarRent Manager application.
///
/// - Singleton instance via [DatabaseHelper.instance]
/// - Ensures a single open [Database] connection
/// - Applies schema migrations on creation / upgrade
class DatabaseHelper {
  static const _databaseName = 'car_rent_manager.db';
  static const _databaseVersion = 5;

  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _database;

  /// Lazily opens the database if it is not already open.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Enable foreign key constraints.
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Creates the initial database schema (version 1).
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // vehicles table
    batch.execute('''
      CREATE TABLE vehicles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        registration_number TEXT NOT NULL UNIQUE,
        year INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'available',
        daily_price REAL NOT NULL DEFAULT 0,
        image_path TEXT,
        image_blob BLOB,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // clients table
    batch.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        cin TEXT NOT NULL UNIQUE,
        license_number TEXT NOT NULL,
        address TEXT,
        phone TEXT NOT NULL,
        email TEXT,
        cin_image_path TEXT,
        license_image_path TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        license_expiry_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_clients_license_unique ON clients(license_number)',
    );

    // contracts table
    batch.execute('''
      CREATE TABLE contracts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contract_number TEXT NOT NULL UNIQUE,
        vehicle_id INTEGER NOT NULL,
        primary_driver_id INTEGER NOT NULL,
        secondary_driver_id INTEGER,
        start_date TEXT NOT NULL,
        expected_return_date TEXT NOT NULL,
        actual_return_date TEXT,
        total_price REAL NOT NULL,
        amount_paid REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
        FOREIGN KEY (primary_driver_id) REFERENCES clients(id),
        FOREIGN KEY (secondary_driver_id) REFERENCES clients(id)
      );
    ''');

    // payments table
    batch.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contract_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (contract_id) REFERENCES contracts(id)
      );
    ''');

    // app_settings table
    batch.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // license_data table
    batch.execute('''
      CREATE TABLE license_data (
        id INTEGER PRIMARY KEY,
        license_key TEXT NOT NULL,
        company_id TEXT NOT NULL,
        expiry_date TEXT NOT NULL,
        last_verified_date TEXT NOT NULL,
        is_valid INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await batch.commit(noResult: true);
  }

  /// Handles schema upgrades between versions.
  ///
  /// Currently only version 1 exists, so this is a no-op, but the method
  /// is implemented for forward compatibility.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Soft-delete support for clients.
      await db.execute(
        "ALTER TABLE clients ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0",
      );
      // Backfill existing rows (SQLite may set NULL for existing records).
      await db.execute(
        "UPDATE clients SET is_archived = 0 WHERE is_archived IS NULL",
      );
    }
    if (oldVersion < 3) {
      // Enforce unique license numbers (best-effort; may fail if duplicates exist).
      try {
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_clients_license_unique ON clients(license_number)',
        );
      } catch (_) {
        // If existing data contains duplicates, keep running; app-layer checks will handle.
      }
    }
    if (oldVersion < 4) {
      // Add image_blob column to vehicles table if it doesn't exist.
      try {
        await db.execute(
          "ALTER TABLE vehicles ADD COLUMN image_blob BLOB",
        );
      } catch (e) {
        // Column might already exist if migration partially ran.
      }
    }
    if (oldVersion < 5) {
      // Add license_expiry_date support for clients.
      try {
        await db.execute(
          "ALTER TABLE clients ADD COLUMN license_expiry_date TEXT",
        );
      } catch (e) {
        // Column might already exist.
      }
    }
  }

  /// Closes the database if it is open.
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}

