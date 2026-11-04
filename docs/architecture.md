# Architecture direction

CarRent Manager is moving to Clean Architecture feature by feature. Existing
features stay operational while new work follows these boundaries:

- `presentation/`: Flutter screens, widgets, Riverpod providers, and routing.
- `domain/`: entities, business rules, repository interfaces, and use cases.
- `data/`: SQLite models, mappers, and implementations of domain repositories.
- `core/`: shared technical services such as localization, notifications, PDF,
  security, and storage.

## First migrated feature: reservations

The availability and quote workflow now demonstrates the intended direction:

1. `Reservation` is a domain entity with no SQLite or Flutter imports.
2. `CreateReservationQuote`, `ListReservations`, and
   `CancelReservationQuote` contain the application actions.
3. `ReservationRepository` is the domain storage contract.
4. `SqliteReservationRepository` performs the SQLite work and maps rows using
   `ReservationModel`.
5. The availability screen depends on use cases through Riverpod providers,
   not on SQLite classes directly.

## Second migrated feature: today’s operations

The dashboard queue now uses `BuildTodayOperations`. The data layer maps
contracts and vehicles into small operational domain entities, the use case
decides which items need attention, and the screen only formats localized
labels and navigates to the relevant record.

## Third migrated action: contract payments

`RecordContractPayment` owns the payment validation and depends on a narrow
domain repository contract. Its SQLite implementation performs the existing
atomic payment-and-balance update. Contract detail screens now invoke this use
case through a provider rather than calling the contract repository directly.

The contract creation form also delegates client creation, contract-number
generation, persistence, cache refreshes, and reminder setup to providers.
This removes its direct dependency on client and contract repositories.

## Fourth migrated feature: global search

`SearchAgency` returns domain search items for clients, vehicles, and
contracts. The global search widget only renders and routes those items; the
SQLite queries and model mapping are contained in `SqliteAgencySearchRepository`.

New features should follow this pattern. Existing areas will be migrated when
they are enhanced, beginning with contracts and payments.

## Offline assistant

`lib/core/assistant/` answers questions about the agency's data in two modes.
`AssistantService` first retrieves the small, relevant slice of local SQLite
data through a read-only store (no embeddings, no index to maintain). Without a
model, that retrieved text is the answer. If the operator has loaded a `.gguf`
model, `GemmaRuntimeService` (llama.cpp via `llama_flutter_android`) rewrites
it, and the result is rejected in favour of the retrieved answer when it does
not preserve the facts. Android only; everything runs on the device.
