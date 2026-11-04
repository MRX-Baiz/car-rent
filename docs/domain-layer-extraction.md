# Domain Layer Extraction: Reminders and Backup

This document describes the clean-architecture migration of reminder scheduling and backup functionality into a domain layer.

## Motivation

Previously, reminders and backup were tightly coupled:
- **Presentation layer** called `NotificationService` and `BackupService` directly
- **Notifiers** `(ContractNotifier, VehicleNotifier)` owned reminder orchestration logic (when to arm, clear, restore)
- **Screens** (settings, splash) duplicated this orchestration
- Business rules (e.g., *only active contracts have reminders; deleted ones have none*) lived in imperative code, not testable in isolation

## Architecture After

### Domain Layer
The business rules now live here, testable without mocks:

**Entities** (`lib/domain/entities/`):
- `NotificationPreferences`: what the operator has chosen
- `NotificationDiagnostics`: whether the OS will honour those choices
- `ContractReminderPlan`, `VehicleMaintenancePlan`: contracts and vehicles, shaped as what reminders need (no `id?`, no persistence details)
- `ReminderSettings`, `ReminderPreferencesResult`: DTOs for the settings workflow

**Services** (ports the domain depends on):
- `ReminderScheduler` (abstract): schedule/cancel/load diagnostics, request permission
- Implementation: `NotificationReminderScheduler` (in data layer)

**Repositories** (ports, with implementations in data layer):
- `ReminderSourceRepository`: read contracts and vehicles as plans (not models)
- `ReminderPreferencesRepository`: load/save user preferences
- `BackupRepository`: create/restore backup archives

**Use Cases** (`lib/domain/usecases/`):
- `SyncContractReminders`: arm/clear one contract after a change
- `RestoreContractReminders`: re-arm all contracts (for launch, settings change)
- `SyncVehicleMaintenanceReminders`: arm one vehicle after save
- `RestoreRemindersOnLaunch`: orchestrates all four at startup
- `LoadReminderSettings`, `RequestReminderPermissions`, `ChangeReminderPreferences`: settings workflows
- `CreateBackup`, `RestoreBackup`: backup workflows

### Data Layer Adapters
- `NotificationReminderScheduler`: wraps `NotificationService`, speaks domain plans
- `SqliteReminderSourceRepository`: reads SQLite, shapes as domain plans
- `ZipBackupRepository`: wraps `BackupService.createBackup/restoreBackup`
- `NotificationPreferencesRepository`: implements `ReminderPreferencesRepository`

**Boundary**: data imports domain services/repositories only; does not export concrete models.

### Presentation Layer
- **Providers** (`reminder_provider.dart`, `backup_provider.dart`) wire adapters → use cases
- **Notifiers** (`ContractNotifier`, `VehicleNotifier`) call use-case providers after mutations:
  - `await ref.read(syncContractRemindersProvider)(id)` instead of `await NotificationService.instance.cancelContractNotifications(id)`
- **Screens**:
  - `SplashScreen` calls `restoreRemindersOnLaunchProvider` once at startup
  - `SettingsScreen` calls domain use cases for preferences/permissions/backup workflows
- **Zero direct calls** to `NotificationService` or `BackupService` from presentation

## Testing

### 18 new domain tests pass with fakes
No mocks of real services; logic validated against simple in-memory test doubles:
- `SyncContractReminders`: active/inactive contracts, permission passthrough
- `RestoreContractReminders`: batch arm/clear with optional permission prompt
- `ChangeReminderPreferences`: permission refusal, savings, re-arming on enable, cancellation on disable
- Backup restore: validates archive before clearing alarms, clears on validation, re-arms after restore

Tests verify rules without touching Android notifications or the filesystem.

## Migration Checklist

For other domains (clients, vehicles, payments, etc.), follow this pattern:

1. **Define domain**:
   - Entities (business data, read-only structures)
   - Services (ports: what the domain needs from the outside world)
   - Repositories (ports: how to read/write persistent or external data)
   - Use cases (rules: when to do what, holding state machines and validation)

2. **Create data adapters**:
   - Implement each repository port over the existing storage layer
   - Implement each service port over the existing platform/device APIs
   - Transform persistence models to domain entities at the boundary

3. **Build presentation wiring**:
   - Providers that compose data adapters into use cases
   - Notifiers/screens call use-case providers instead of repositories/services directly

4. **Write domain tests**:
   - Test rules with fakes, no mocks of real services
   - Exercise state transitions, validation, error cases
   - One test per rule makes the intent clear

5. **Update callers**:
   - Screens, notifiers, startup paths call domain use cases
   - Delete any business logic that was duplicated

## Next: Clients, Vehicles, Payments

The migration leaves repositories (`ClientRepository`, `VehicleRepository`, `PaymentRepository`) still callable directly from presentation. These should follow the same pattern: define domain use cases, implement repositories as data adapters, wire through providers.

Priority areas:
- **Clients/vehicles**: high coupling in forms, detail screens
- **Payments**: `PaymentNotifier` and `PaymentRepository` are tightly bound
- **Contracts**: already partially migrated; finish payment/inspection domains
