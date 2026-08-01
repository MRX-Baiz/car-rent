/// Migration definitions for database version 1.
///
/// The initial schema is applied in [DatabaseHelper._onCreate].
/// This file holds SQL strings for reference and potential reuse
/// (e.g. in tests or documentation).

class MigrationV1 {
  static const String createVehicles = '''
    CREATE TABLE vehicles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      brand TEXT NOT NULL,
      model TEXT NOT NULL,
      registration_number TEXT NOT NULL UNIQUE,
      year INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'available',
      daily_price REAL NOT NULL DEFAULT 0,
      image_path TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createClients = '''
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
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createContracts = '''
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
  ''';

  static const String createPayments = '''
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
  ''';

  static const String createAppSettings = '''
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  ''';

  static const String createLicenseData = '''
    CREATE TABLE license_data (
      id INTEGER PRIMARY KEY,
      license_key TEXT NOT NULL,
      company_id TEXT NOT NULL,
      expiry_date TEXT NOT NULL,
      last_verified_date TEXT NOT NULL,
      is_valid INTEGER NOT NULL DEFAULT 0
    );
  ''';
}
