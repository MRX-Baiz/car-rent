import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Central SQLite access point for the CarRent Manager application.
///
/// - Singleton instance via [DatabaseHelper.instance]
/// - Ensures a single open [Database] connection
/// - Applies schema migrations on creation / upgrade
class DatabaseHelper {
  static const _databaseName = 'car_rent_manager.db';
  static const _databaseVersion = 8;

  static const _createContractDocuments = '''
    CREATE TABLE contract_documents (
      contract_id INTEGER PRIMARY KEY REFERENCES contracts(id) ON DELETE CASCADE,
      original_path TEXT NOT NULL,
      original_hash TEXT NOT NULL,
      signed_path TEXT,
      signed_hash TEXT,
      signature_path TEXT,
      method TEXT NOT NULL DEFAULT 'pending',
      prepared_at TEXT NOT NULL,
      recorded_at TEXT,
      signer_name TEXT NOT NULL,
      signer_cin TEXT NOT NULL,
      signer_license TEXT NOT NULL,
      terms_json TEXT NOT NULL
    )
  ''';

  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _database;

  /// The file copied into a backup archive. The database is closed before it
  /// is read, so SQLite has flushed every change to this file.
  Future<File> get databaseFile async {
    final dbPath = await getDatabasesPath();
    return File(p.join(dbPath, _databaseName));
  }

  /// Lazily opens the database if it is not already open.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Opens an independent SQLite connection that rejects every write. This is
  /// used by the local assistant so its data layer cannot change agency data.
  /// Callers own this connection and must close it when their read is done.
  Future<Database> openAssistantReadOnlyDatabase() async {
    // Ensure creation and migrations have completed before a read-only handle
    // tries to open the file for the first time.
    await database;
    final dbPath = await getDatabasesPath();
    return openReadOnlyDatabase(
      p.join(dbPath, _databaseName),
      singleInstance: false,
    );
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
        transmission TEXT NOT NULL DEFAULT 'manual',
        fuel_type TEXT NOT NULL DEFAULT 'petrol',
        condition_status TEXT NOT NULL DEFAULT 'good',
        current_mileage INTEGER NOT NULL DEFAULT 0,
        fuel_level INTEGER NOT NULL DEFAULT 100,
        insurance_expiry_date TEXT,
        technical_inspection_expiry_date TEXT,
        vignette_due_date TEXT,
        oil_change_due_date TEXT,
        oil_change_due_mileage INTEGER,
        distribution_due_date TEXT,
        distribution_due_mileage INTEGER,
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

    batch.execute('''
      CREATE TABLE chauffeurs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        cin TEXT NOT NULL UNIQUE,
        license_number TEXT NOT NULL UNIQUE,
        phone TEXT NOT NULL,
        license_expiry_date TEXT,
        hourly_rate REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'available',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // contracts table
    batch.execute('''
      CREATE TABLE contracts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contract_number TEXT NOT NULL UNIQUE,
        vehicle_id INTEGER NOT NULL,
        primary_driver_id INTEGER NOT NULL,
        secondary_driver_id INTEGER,
        chauffeur_id INTEGER,
        chauffeur_hours REAL NOT NULL DEFAULT 0,
        chauffeur_hourly_rate REAL NOT NULL DEFAULT 0,
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
        ,FOREIGN KEY (chauffeur_id) REFERENCES chauffeurs(id)
      );
    ''');

    // Quotes reserve a vehicle for a defined period before they become a
    // signed rental contract. Keeping them separate makes the calendar useful
    // to the team without creating a customer-facing contract too early.
    batch.execute('''
      CREATE TABLE reservations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL,
        client_id INTEGER,
        start_date TEXT NOT NULL,
        expected_return_date TEXT NOT NULL,
        daily_price REAL NOT NULL DEFAULT 0,
        total_price REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'quote',
        notes TEXT,
        converted_contract_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
        FOREIGN KEY (client_id) REFERENCES clients(id),
        FOREIGN KEY (converted_contract_id) REFERENCES contracts(id)
      );
    ''');
    batch.execute(
      'CREATE INDEX idx_reservations_vehicle_dates ON reservations(vehicle_id, start_date, expected_return_date)',
    );

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

    batch.execute(_createContractDocuments);
    batch.execute('''
      CREATE TABLE vehicle_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL,
        kind TEXT NOT NULL,
        path TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('''
      CREATE TABLE contract_inspections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contract_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        mileage INTEGER NOT NULL,
        fuel_level INTEGER NOT NULL,
        condition_status TEXT NOT NULL,
        damage_notes TEXT,
        extra_charges REAL NOT NULL DEFAULT 0,
        signature_path TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(contract_id, type),
        FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('''
      CREATE TABLE inspection_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_id INTEGER NOT NULL,
        kind TEXT NOT NULL,
        path TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (inspection_id) REFERENCES contract_inspections(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('''
      CREATE TABLE vehicle_alert_history (
        vehicle_id INTEGER NOT NULL,
        alert_key TEXT NOT NULL,
        threshold INTEGER NOT NULL,
        due_mileage INTEGER NOT NULL,
        PRIMARY KEY (vehicle_id, alert_key, threshold)
      );
    ''');
    await batch.commit(noResult: true);
  }

  /// Handles schema upgrades between versions.
  ///
  /// Currently only version 1 exists, so this is a no-op, but the method
  /// is implemented for forward compatibility.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 8) {
      await db.execute('''CREATE TABLE IF NOT EXISTS reservations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL,
        client_id INTEGER,
        start_date TEXT NOT NULL,
        expected_return_date TEXT NOT NULL,
        daily_price REAL NOT NULL DEFAULT 0,
        total_price REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'quote',
        notes TEXT,
        converted_contract_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
        FOREIGN KEY (client_id) REFERENCES clients(id),
        FOREIGN KEY (converted_contract_id) REFERENCES contracts(id)
      )''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reservations_vehicle_dates ON reservations(vehicle_id, start_date, expected_return_date)',
      );
    }
    if (oldVersion < 7) {
      const vehicleColumns = <String>[
        "transmission TEXT NOT NULL DEFAULT 'manual'",
        "fuel_type TEXT NOT NULL DEFAULT 'petrol'",
        "condition_status TEXT NOT NULL DEFAULT 'good'",
        'current_mileage INTEGER NOT NULL DEFAULT 0',
        'fuel_level INTEGER NOT NULL DEFAULT 100',
        'insurance_expiry_date TEXT',
        'technical_inspection_expiry_date TEXT',
        'vignette_due_date TEXT',
        'oil_change_due_date TEXT',
        'oil_change_due_mileage INTEGER',
        'distribution_due_date TEXT',
        'distribution_due_mileage INTEGER',
      ];
      for (final column in vehicleColumns) {
        try {
          await db.execute('ALTER TABLE vehicles ADD COLUMN $column');
        } catch (_) {}
      }
      await db.execute('''CREATE TABLE IF NOT EXISTS chauffeurs (
        id INTEGER PRIMARY KEY AUTOINCREMENT, first_name TEXT NOT NULL, last_name TEXT NOT NULL,
        cin TEXT NOT NULL UNIQUE, license_number TEXT NOT NULL UNIQUE, phone TEXT NOT NULL,
        license_expiry_date TEXT, hourly_rate REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'available', notes TEXT,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
      for (final column in <String>[
        'chauffeur_id INTEGER',
        'chauffeur_hours REAL NOT NULL DEFAULT 0',
        'chauffeur_hourly_rate REAL NOT NULL DEFAULT 0',
      ]) {
        try {
          await db.execute('ALTER TABLE contracts ADD COLUMN $column');
        } catch (_) {}
      }
      await db.execute('''CREATE TABLE IF NOT EXISTS vehicle_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT, vehicle_id INTEGER NOT NULL, kind TEXT NOT NULL,
        path TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE)''');
      await db.execute('''CREATE TABLE IF NOT EXISTS contract_inspections (
        id INTEGER PRIMARY KEY AUTOINCREMENT, contract_id INTEGER NOT NULL, type TEXT NOT NULL,
        mileage INTEGER NOT NULL, fuel_level INTEGER NOT NULL, condition_status TEXT NOT NULL,
        damage_notes TEXT, extra_charges REAL NOT NULL DEFAULT 0, signature_path TEXT,
        created_at TEXT NOT NULL, UNIQUE(contract_id, type),
        FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE CASCADE)''');
      await db.execute('''CREATE TABLE IF NOT EXISTS inspection_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT, inspection_id INTEGER NOT NULL, kind TEXT NOT NULL,
        path TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL,
        FOREIGN KEY (inspection_id) REFERENCES contract_inspections(id) ON DELETE CASCADE)''');
      await db.execute('''CREATE TABLE IF NOT EXISTS vehicle_alert_history (
        vehicle_id INTEGER NOT NULL, alert_key TEXT NOT NULL, threshold INTEGER NOT NULL,
        due_mileage INTEGER NOT NULL, PRIMARY KEY (vehicle_id, alert_key, threshold))''');
    }
    if (oldVersion < 6) {
      await db.execute(_createContractDocuments);
    }
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
