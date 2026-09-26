import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/core/utils/format_utils.dart';
import 'package:car_rent_manager/data/models/client_model.dart';
import 'package:car_rent_manager/data/models/contract_model.dart';
import 'package:car_rent_manager/data/models/vehicle_model.dart';
import 'package:car_rent_manager/domain/entities/reservation.dart';
import 'package:car_rent_manager/domain/usecases/booking_availability.dart';
import 'package:car_rent_manager/presentation/providers/client_provider.dart';
import 'package:car_rent_manager/presentation/providers/contract_provider.dart';
import 'package:car_rent_manager/presentation/providers/reservation_provider.dart';
import 'package:car_rent_manager/presentation/providers/vehicle_provider.dart';
import 'package:car_rent_manager/presentation/widgets/common/adaptive_layout.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_card.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:car_rent_manager/presentation/widgets/common/empty_state_widget.dart';
import 'package:car_rent_manager/presentation/widgets/motion/backdrop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AvailabilityCalendarScreen extends ConsumerStatefulWidget {
  const AvailabilityCalendarScreen({super.key});

  @override
  ConsumerState<AvailabilityCalendarScreen> createState() =>
      _AvailabilityCalendarScreenState();
}

class _AvailabilityCalendarScreenState
    extends ConsumerState<AvailabilityCalendarScreen> {
  late DateTime _weekStart;
  List<Reservation> _reservations = const [];
  bool _loadingReservations = true;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _weekStart = today.subtract(Duration(days: today.weekday - 1));
    Future.microtask(() async {
      await Future.wait([
        ref.read(vehiclesProvider.notifier).loadVehicles(),
        ref.read(clientsProvider.notifier).loadClients(),
        ref.read(contractsProvider.notifier).loadContracts(),
      ]);
      await _loadReservations();
    });
  }

  Future<void> _loadReservations() async {
    if (mounted) setState(() => _loadingReservations = true);
    final reservations = await ref.read(reservationsProvider.future);
    if (mounted) {
      setState(() {
        _reservations = reservations;
        _loadingReservations = false;
      });
    }
  }

  List<DateTime> get _days => List.generate(
        7,
        (index) => _weekStart.add(Duration(days: index)),
      );

  bool _overlaps(DateTime start, DateTime end, DateTime day) {
    final nextDay = day.add(const Duration(days: 1));
    return bookingIntervalsOverlap(start, end, day, nextDay);
  }

  _CalendarState _stateFor(
      VehicleModel vehicle, DateTime day, List<ContractModel> contracts) {
    if (vehicle.status == 'maintenance') return _CalendarState.maintenance;
    if (contracts.any((contract) =>
        contract.vehicleId == vehicle.id &&
        contract.status == 'active' &&
        _overlaps(contract.startDate, contract.expectedReturnDate, day))) {
      return _CalendarState.contract;
    }
    if (_reservations.any((reservation) =>
        reservation.vehicleId == vehicle.id &&
        reservation.blocksAvailability &&
        _overlaps(
            reservation.startDate, reservation.expectedReturnDate, day))) {
      return _CalendarState.quote;
    }
    return _CalendarState.available;
  }

  Future<void> _showQuoteSheet(VehicleModel vehicle,
      {DateTime? initialStart}) async {
    DateTime start = initialStart ?? _weekStart;
    DateTime end = start.add(const Duration(days: 1));
    double dailyPrice = 0;
    ClientModel? client;
    final dailyController = TextEditingController();
    final clients = ref.read(clientsProvider).value ?? const <ClientModel>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final days = end.difference(start).inDays;
          final total = dailyPrice * (days < 1 ? 1 : days);
          Future<void> pickDate(bool isStart) async {
            final picked = await showDatePicker(
              context: context,
              initialDate: isStart ? start : end,
              firstDate: dateOnly(DateTime.now()),
              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
            );
            if (picked == null) return;
            setSheetState(() {
              if (isStart) {
                start = picked;
                if (!end.isAfter(start))
                  end = start.add(const Duration(days: 1));
              } else if (picked.isAfter(start)) {
                end = picked;
              }
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(AppCopy.newQuote,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                        '${vehicle.brand} ${vehicle.model} · ${vehicle.registrationNumber}'),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: _DateButton(
                          label: AppCopy.startDate,
                          value: formatDate(start),
                          onTap: () => pickDate(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateButton(
                          label: AppCopy.returnDate,
                          value: formatDate(end),
                          onTap: () => pickDate(false),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ClientModel?>(
                      value: client,
                      isExpanded: true,
                      decoration: InputDecoration(
                          labelText: context.tr(AppCopy.clientOptional)),
                      items: [
                        const DropdownMenuItem<ClientModel?>(
                          value: null,
                          child: AppText(AppCopy.noClient),
                        ),
                        ...clients.map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.fullName,
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (value) => setSheetState(() => client = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: dailyController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: context.tr(AppCopy.dailyPrice),
                        suffixText: 'MAD',
                      ),
                      onChanged: (value) => setSheetState(
                        () => dailyPrice =
                            double.tryParse(value.replaceAll(',', '.')) ?? 0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Row(children: [
                        const Icon(Icons.calculate_outlined),
                        const SizedBox(width: 12),
                        Expanded(child: AppText(AppCopy.estimatedTotal)),
                        AppText(context.money(total),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    const AppText(AppCopy.thisQuoteBlocksTheVehicleUntilItIs,
                        style: TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const AppText(AppCopy.saveQuote),
                        onPressed: () async {
                          try {
                            final now = DateTime.now();
                            await ref.read(createReservationQuoteProvider)(
                              Reservation(
                                vehicleId: vehicle.id!,
                                clientId: client?.id,
                                startDate: start,
                                expectedReturnDate: end,
                                dailyPrice: dailyPrice,
                                totalPrice: total,
                                createdAt: now,
                                updatedAt: now,
                              ),
                            );
                            if (context.mounted) Navigator.pop(context);
                            ref.invalidate(reservationsProvider);
                            await _loadReservations();
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                    content: AppText(AppCopy.quoteSaved)),
                              );
                            }
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: AppText(error
                                        .toString()
                                        .replaceFirst('Exception: ', ''))),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    dailyController.dispose();
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    await ref.read(cancelReservationQuoteProvider)(reservation.id!);
    ref.invalidate(reservationsProvider);
    await _loadReservations();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText(AppCopy.reservationCancelled)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles =
        ref.watch(vehiclesProvider).value ?? const <VehicleModel>[];
    final contracts =
        ref.watch(contractsProvider).value ?? const <ContractModel>[];
    final clients = ref.watch(clientsProvider).value ?? const <ClientModel>[];

    return AdaptiveLayout(
      child: Scaffold(
        appBar: AppBar(
          title: const AppText(AppCopy.availabilityCalendar),
          actions: [
            IconButton(
              tooltip: context.tr(AppCopy.today),
              icon: const Icon(Icons.today_outlined),
              onPressed: () {
                final today = dateOnly(DateTime.now());
                setState(() => _weekStart =
                    today.subtract(Duration(days: today.weekday - 1)));
              },
            ),
          ],
        ),
        body: BackdropPage(
          child: RefreshIndicator(
            onRefresh: _loadReservations,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
              children: [
                _weekSelector(context),
                const SizedBox(height: 12),
                _legend(context),
                const SizedBox(height: 12),
                if (vehicles.isEmpty)
                  const SizedBox(
                    height: 320,
                    child: EmptyStateWidget(
                      title: AppCopy.noVehicles,
                      subtitle: AppCopy.addAVehicleToPlanReservations,
                      icon: Icons.directions_car_outlined,
                    ),
                  )
                else
                  _calendar(context, vehicles, contracts),
                const SizedBox(height: 24),
                AppText(AppCopy.savedQuotes,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                if (_loadingReservations)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator()))
                else
                  _quotes(context, vehicles, clients),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weekSelector(BuildContext context) => AppCard(
        child: Row(children: [
          IconButton(
            tooltip: context.tr(AppCopy.previousWeek),
            onPressed: () => setState(() =>
                _weekStart = _weekStart.subtract(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(children: [
              const AppText(AppCopy.availabilityCalendarb8c1ea,
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              AppText(
                  '${DateFormat('d MMM', Localizations.localeOf(context).toLanguageTag()).format(_weekStart)} – ${DateFormat('d MMM yyyy', Localizations.localeOf(context).toLanguageTag()).format(_weekStart.add(const Duration(days: 6)))}'),
            ]),
          ),
          IconButton(
            tooltip: context.tr(AppCopy.nextWeek),
            onPressed: () => setState(
                () => _weekStart = _weekStart.add(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
      );

  Widget _legend(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _LegendItem(label: AppCopy.available, color: const Color(0xFFDDF7E8)),
          _LegendItem(label: AppCopy.quote, color: const Color(0xFFFFE8B7)),
          _LegendItem(label: AppCopy.contract, color: const Color(0xFFFFD9D9)),
          _LegendItem(
              label: AppCopy.maintenance799eec, color: const Color(0xFFE2E8F0)),
        ],
      );

  Widget _calendar(BuildContext context, List<VehicleModel> vehicles,
      List<ContractModel> contracts) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 780,
        child: Column(children: [
          Row(children: [
            const SizedBox(width: 174),
            for (final day in _days)
              SizedBox(
                width: 86,
                child: Column(children: [
                  AppText(DateFormat('EEE', locale).format(day),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  AppText('${day.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: dateOnly(day) == dateOnly(DateTime.now())
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      )),
                ]),
              ),
          ]),
          const SizedBox(height: 8),
          for (final vehicle in vehicles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(
                  width: 174,
                  child: Text(
                      '${vehicle.brand} ${vehicle.model}\n${vehicle.registrationNumber}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                for (final day in _days)
                  _CalendarCell(
                    state: _stateFor(vehicle, day, contracts),
                    onTap: vehicle.status == 'maintenance'
                        ? null
                        : () => _showQuoteSheet(vehicle, initialStart: day),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _quotes(BuildContext context, List<VehicleModel> vehicles,
      List<ClientModel> clients) {
    final quotes =
        _reservations.where((item) => item.status == 'quote').toList();
    if (quotes.isEmpty) {
      return const AppCard(
        child: AppText(AppCopy.noSavedQuotes),
      );
    }
    return Column(
      children: quotes.map((quote) {
        final vehicle =
            vehicles.where((item) => item.id == quote.vehicleId).firstOrNull;
        final client =
            clients.where((item) => item.id == quote.clientId).firstOrNull;
        return AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.bookmark_outline),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      vehicle == null
                          ? AppCopy.vehicle
                          : '${vehicle.brand} ${vehicle.model}',
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              AppText(context.money(quote.totalPrice),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            AppText(context.messages.rentalDateRange(
                (formatDate(quote.startDate)).toString(),
                (formatDate(quote.expectedReturnDate)).toString(),
                (quote.rentalDays).toString())),
            if (client != null) Text(client.fullName),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 18),
                label: const AppText(AppCopy.cancelReservation),
                onPressed: () => _cancelReservation(quote),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const AppText(AppCopy.convertToContract),
                onPressed: () => context.push('/contracts/new', extra: quote),
              ),
            ]),
          ]),
        );
      }).toList(),
    );
  }
}

enum _CalendarState { available, quote, contract, maintenance }

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({required this.state, this.onTap});
  final _CalendarState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final values = switch (state) {
      _CalendarState.available => (const Color(0xFFDDF7E8), AppCopy.available),
      _CalendarState.quote => (const Color(0xFFFFE8B7), AppCopy.quote),
      _CalendarState.contract => (const Color(0xFFFFD9D9), AppCopy.contract),
      _CalendarState.maintenance => (
          const Color(0xFFE2E8F0),
          AppCopy.maintenance799eec
        ),
    };
    return SizedBox(
      width: 86,
      height: 58,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: values.$1,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Center(
                child: AppText(values.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700))),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(20)),
        child: AppText(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _DateButton extends StatelessWidget {
  const _DateButton(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppText(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          AppText(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
