# CarRent Manager

Offline-first vehicle rental management for small agencies, built with Flutter.
One operator, one phone: vehicles, clients, contracts, payments, signed PDF
contracts, on-device OCR of identity documents, and local reminders for return
deadlines. No server, no account, no network required.

Android is the primary target. iOS, macOS and Windows build from the same
codebase.

## Features

- **Fleet and clients** — vehicles with photos, expenses and maintenance dates;
  clients with scanned CIN / driving-licence attachments.
- **Contracts and payments** — create, edit and close contracts, record
  payments, and track balances. Double-booking of a vehicle or chauffeur is
  refused at the repository level.
- **Reservations** — availability calendar with plate search, and quotes that
  convert into contracts.
- **Contract PDFs and signatures** — one permanent original per contract,
  signed on the phone or returned signed by the client, archived with its
  SHA-256.
- **On-device OCR** — Moroccan CIN and driving-licence field extraction using
  ML Kit (Android) or Apple Vision (macOS). No OCR server to deploy.
- **Local notifications** — return and payment reminders, a daily overdue
  repeat, and restoration after a phone restart.
- **Offline assistant (RAG)** — ask questions about your own agency data
  (overdue returns, balances, vehicle status). It works in two modes:
  - *Without a model*: retrieval alone. The question is matched against a
    read-only view of the local SQLite data and answered from the retrieved
    facts.
  - *With a small on-device LLM*: load a Gemma `.gguf` model (run through
    llama.cpp) and the same retrieved facts are passed to it for a more natural
    answer. Its output is checked against the facts and discarded in favour of
    the retrieved answer if it drops them. Nothing leaves the phone.
- **Security** — 6-digit PIN (PBKDF2-HMAC-SHA256) with lockout ladder and
  optional biometrics; two-tier PIN recovery.
- **Licensing** — RSA-4096 signed, device-bound, verified fully offline, with
  per-customer feature flags (vehicle profitability, customer history).
- **Backup and restore** — a single ZIP including attachments and signed PDFs.
- **Localization** — French, English and Arabic, including right-to-left layout.

## Architecture

Clean architecture applied feature by feature:

```
lib/
  presentation/   screens, widgets, Riverpod providers, routing
  domain/         entities, repository ports, pure use cases (no Flutter/SQLite)
  data/           SQLite models, mappers, repository implementations
  core/           licensing, security, notifications, OCR, PDF, storage, l10n
```

Business rules such as availability, profitability and customer history are
pure use cases tested with plain objects. See
[docs/architecture.md](docs/architecture.md) for the reasoning and
[CLAUDE.md](CLAUDE.md) for the design decisions behind the parts that do not
look like a first draft (back-button handling, attachment storage,
notification delivery, licence compatibility).

## Getting started

Requires Flutter 3.44 (stable).

```bash
flutter pub get
flutter run
```

Quality gates:

```bash
flutter analyze   # no issues
flutter test      # 301 tests
```

Build and release instructions are in [docs/building.md](docs/building.md);
licence issuing is covered in [docs/licensing.md](docs/licensing.md).

## Tech stack

Flutter · Riverpod · go_router · sqflite · flutter_local_notifications ·
fast_rsa · local_auth · pdf / printing · ML Kit / Apple Vision OCR ·
llama.cpp (on-device Gemma)
