import 'package:flutter/widgets.dart';
import '../localization/app_localizations.dart';
import '../../data/models/chauffeur_model.dart';
import '../../data/models/client_model.dart';
import '../../data/models/contract_model.dart';
import '../../data/models/vehicle_model.dart';
import 'assistant_models.dart';
import 'gemma_runtime_service.dart';
import 'assistant_read_only_store.dart';

/// Retrieves only the small, relevant part of the local SQLite data first.
/// This is the first RAG layer: indexed operational data is never embedded or
/// scanned as a whole. Semantic HNSW search can later index free-text notes.
class AssistantService {
  AssistantService._();
  static final instance = AssistantService._();
  void refreshAgencyData() => AssistantReadOnlyStore.instance.invalidate();
  Future<AssistantAnswer> answer(String question, {String languageCode = 'fr'}) =>
      _AssistantQuery(languageCode).answer(question);
}

class _AssistantQuery {
  _AssistantQuery(this.languageCode);
  final String languageCode;
  AppMessages get messages => lookupAppMessages(Locale(languageCode));
  String tr(String source) => AppLocalizations.translate(Locale(languageCode), source);
  String status(String source) => tr(const {
    'active': 'En cours', 'completed': 'Terminé', 'late': 'En retard',
    'available': 'Disponible', 'rented': 'Loué', 'maintenance': 'Maintenance',
    'assigned': 'Occupé', 'good': 'Bon état', 'check': 'À contrôler', 'damaged': 'Endommagé',
  }[source] ?? source);

  final _readOnly = AssistantReadOnlyStore.instance;
  final _gemma = GemmaRuntimeService.instance;

  /// Call this when opening the assistant after changing agency records.
  /// The next question rebuilds the snapshot through the read-only handle.
  void refreshAgencyData() => _readOnly.invalidate();

  Future<AssistantAnswer> answer(String rawQuestion) async {
    final question = rawQuestion.trim();
    if (question.isEmpty) {
      return AssistantAnswer(text: messages.assistantWriteQuestion);
    }
    final normalized = _normalize(question);
    final retrieved = await _retrieve(normalized);
    if (!_gemma.status.isLoaded) return retrieved;

    try {
      // General questions have no agency facts to retrieve. Let the owner use
      // the installed model as a normal private chatbot, without passing any
      // database content into that conversation.
      if (retrieved.allowDirectModel) {
        return AssistantAnswer(
          text: await _gemma.answerGeneralQuestion(question, languageCode: languageCode),
          enhancedByModel: true,
        );
      }
      final enhanced = await _gemma.improveAnswer(
        question: question,
        facts: retrieved.text,
        languageCode: languageCode,
      );
      // A local SLM must never become the source of an operational answer.
      // Gemma 270M can sometimes answer with a fluent but generic sentence;
      // accept a rewrite only when it preserves every concrete identifier
      // returned by SQLite (contract number, vehicle plate, amount, date).
      if (!_preservesEvidence(enhanced, retrieved.text)) {
        return retrieved;
      }
      return AssistantAnswer(
        text: enhanced,
        actions: retrieved.actions,
        enhancedByModel: enhanced != retrieved.text,
      );
    } catch (_) {
      // The factual answer is still useful if the model runs out of memory.
      return retrieved;
    }
  }

  Future<AssistantAnswer> _retrieve(String question) async {
    final graph = await _readOnly.graph();
    final contract = _resolveContractEntity(question, graph);
    if (contract != null) {
      return _answerForContract(contract, graph);
    }

    final client = _resolveClientEntity(question, graph);
    if (client != null) {
      return _answerForClient(client, graph);
    }

    final chauffeur = _resolveChauffeurEntity(question, graph);
    if (chauffeur != null) {
      return _answerForChauffeur(chauffeur, graph);
    }

    final specificVehicle = _resolveVehicleEntity(question, graph);
    if (specificVehicle != null) {
      return _answerForVehicle(specificVehicle, question, graph);
    }

    if (_contains(question, ['vehicule', 'vehicle', 'voiture', 'cars', 'مركب', 'سيار'])) {
      final wantsAvailable = _contains(
        question,
        ['disponible', 'libre', 'available', 'free', 'متاح'],
      );
      final vehicles = graph.vehicles.values
          .where((vehicle) => !wantsAvailable || vehicle.status == 'available')
          .toList();
      if (vehicles.isEmpty) {
        return AssistantAnswer(
          text: wantsAvailable
              ? messages.assistantNoAvailableCars
              : messages.assistantNoCars,
          actions: [
            AssistantAction(
              label:
                  wantsAvailable ? messages.viewVehicles : messages.addAVehicle,
              route: wantsAvailable ? '/vehicles' : '/vehicles/add',
            ),
          ],
        );
      }
      final names = vehicles.take(12).map(_vehicleName).join(', ');
      final extra =
          vehicles.length > 12 ? messages.assistantMore((vehicles.length - 12).toString()) : '.';
      return AssistantAnswer(
        text: messages.assistantFleet((vehicles.length).toString(), (wantsAvailable ? messages.assistantAvailable : messages.assistantRecorded).toString(), (names).toString(), (extra).toString()),
        actions: [
          AssistantAction(label: messages.viewVehicles, route: '/vehicles')
        ],
      );
    }

    if (_contains(question, ['client', 'clients', 'عميل', 'عملاء'])) {
      final clients = graph.clients.values.toList()
        ..sort((first, second) => first.fullName.compareTo(second.fullName));
      if (clients.isEmpty) {
        return AssistantAnswer(
          text: messages.assistantNoClients,
          actions: [
            AssistantAction(label: messages.addAClient, route: '/clients/add')
          ],
        );
      }
      final names = clients.take(12).map((item) => item.fullName).join(', ');
      final extra =
          clients.length > 12 ? messages.assistantMore((clients.length - 12).toString()) : '.';
      return AssistantAnswer(
        text: messages.assistantClientList((clients.length).toString(), (names).toString(), (extra).toString()),
        actions: [
          AssistantAction(label: messages.viewClients, route: '/clients')
        ],
      );
    }

    if (_contains(question, ['chauffeur', 'chauffeurs', 'driver', 'drivers', 'سائق'])) {
      final chauffeurs = graph.chauffeurs.values.toList()
        ..sort((first, second) => first.fullName.compareTo(second.fullName));
      if (chauffeurs.isEmpty) {
        return AssistantAnswer(
          text: messages.assistantNoDrivers,
          actions: [
            AssistantAction(
                label: messages.addADriver, route: '/chauffeurs/add')
          ],
        );
      }
      final names = chauffeurs.take(12).map((item) => item.fullName).join(', ');
      final extra = chauffeurs.length > 12
          ? messages.assistantMore((chauffeurs.length - 12).toString())
          : '.';
      return AssistantAnswer(
        text: messages.assistantDriverList((chauffeurs.length).toString(), (names).toString(), (extra).toString()),
        actions: [
          AssistantAction(label: messages.viewDrivers, route: '/chauffeurs')
        ],
      );
    }

    if (_contains(question, ['retard', 'en retard', 'late', 'overdue', 'متأخر', 'متاخر'])) {
      final contracts = graph.contracts.values
          .where((item) => item.isLate)
          .toList()
        ..sort((first, second) =>
            first.expectedReturnDate.compareTo(second.expectedReturnDate));
      if (contracts.isEmpty) {
        return AssistantAnswer(
          text: messages.assistantNoLate,
          actions: [
            AssistantAction(label: messages.viewContracts, route: '/contracts')
          ],
        );
      }
      return AssistantAnswer(
        text:
            messages.assistantLateList((contracts.length).toString(), (_contractLines(contracts)).toString()),
        actions: [
          AssistantAction(label: messages.viewContracts, route: '/contracts')
        ],
      );
    }

    if (_contains(question, ['paiement', 'impaye', 'reste', 'solde', 'payment', 'balance', 'مدفوع', 'دفع', 'رصيد'])) {
      final active = graph.contracts.values
          .where((item) => item.status == 'active')
          .toList();
      final unpaid =
          active.where((item) => item.remainingAmount > 0.01).toList();
      if (unpaid.isEmpty) {
        return AssistantAnswer(
          text: messages.assistantNoBalance,
          actions: [
            AssistantAction(label: messages.viewContracts, route: '/contracts')
          ],
        );
      }
      final total =
          unpaid.fold<double>(0, (sum, item) => sum + item.remainingAmount);
      return AssistantAnswer(
        text:
            messages.assistantPaymentList((unpaid.length).toString(), (total.toStringAsFixed(2)).toString(), (_contractLines(unpaid)).toString()),
        actions: [
          AssistantAction(label: messages.viewContracts, route: '/contracts')
        ],
      );
    }

    if (_contains(question, [
      'assurance',
      'visite',
      'vignette',
      'vidange',
      'courroie',
      'chaine',
      'entretien', 'maintenance', 'صيانة',
    ])) {
      final warnings = _maintenanceWarnings(graph.vehicles.values, question);
      if (warnings.isEmpty) {
        return AssistantAnswer(
          text: messages.assistantNoDeadline,
          actions: [
            AssistantAction(label: messages.viewVehicles, route: '/vehicles')
          ],
        );
      }
      return AssistantAnswer(
        text: warnings.join('\n'),
        actions: [
          AssistantAction(label: messages.viewVehicles, route: '/vehicles')
        ],
      );
    }

    if (_contains(question, ['sauvegarde', 'backup', 'restaur', 'نسخ', 'احتياط'])) {
      return AssistantAnswer(
        text:
            messages.assistantBackupHelp,
        actions: [
          AssistantAction(label: messages.openSettings, route: '/settings')
        ],
      );
    }

    if (_contains(
        question, ['etat des lieux', 'inspection', 'depart', 'retour', 'فحص'])) {
      return AssistantAnswer(
        text:
            messages.assistantInspectionHelp,
        actions: [
          AssistantAction(label: messages.viewContracts, route: '/contracts')
        ],
      );
    }

    return AssistantAnswer(
      text:
          messages.assistantHelp,
      allowDirectModel: true,
    );
  }

  /// Resolves the referenced agency entity before choosing a query. It checks
  /// brand, model, and plate, and tolerates a few typing errors in a name.
  /// This is intentionally separate from the user's request words: “detail
  /// Lamborghini” and simply “Lamborghini” resolve to the same vehicle.
  VehicleModel? _resolveVehicleEntity(
      String question, AssistantKnowledgeGraph graph) {
    VehicleModel? best;
    var bestScore = 0.0;
    for (final vehicle in graph.vehicles.values) {
      final identifiers = [
        vehicle.brand,
        vehicle.model,
        vehicle.registrationNumber,
        '${vehicle.brand} ${vehicle.model}',
      ].map(_normalize);
      final score = identifiers
          .map((identifier) => _entityMatchScore(question, identifier))
          .fold<double>(0, (current, item) => item > current ? item : current);
      if (score > bestScore) {
        best = vehicle;
        bestScore = score;
      }
    }
    return bestScore >= .72 ? best : null;
  }

  ContractModel? _resolveContractEntity(
      String question, AssistantKnowledgeGraph graph) {
    return _bestEntity(
      question,
      graph.contracts.values,
      (contract) => [contract.contractNumber],
    );
  }

  ClientModel? _resolveClientEntity(
      String question, AssistantKnowledgeGraph graph) {
    return _bestEntity(
      question,
      graph.clients.values,
      (client) => [client.fullName, client.cin, client.phone],
    );
  }

  ChauffeurModel? _resolveChauffeurEntity(
      String question, AssistantKnowledgeGraph graph) {
    return _bestEntity(
      question,
      graph.chauffeurs.values,
      (chauffeur) => [chauffeur.fullName, chauffeur.cin, chauffeur.phone],
    );
  }

  T? _bestEntity<T>(
    String question,
    Iterable<T> values,
    List<String> Function(T) identifiersFor,
  ) {
    T? best;
    var bestScore = 0.0;
    for (final value in values) {
      final score = identifiersFor(value)
          .map(_normalize)
          .map((identifier) => _entityMatchScore(question, identifier))
          .fold<double>(0, (current, item) => item > current ? item : current);
      if (score > bestScore) {
        best = value;
        bestScore = score;
      }
    }
    return bestScore >= .72 ? best : null;
  }

  AssistantAnswer _answerForContract(
      ContractModel contract, AssistantKnowledgeGraph graph) {
    final vehicle = graph.vehicles[contract.vehicleId];
    final client = graph.clients[contract.primaryDriverId];
    final chauffeur = contract.chauffeurId == null
        ? null
        : graph.chauffeurs[contract.chauffeurId!];
    final payments = graph.paymentsByContract[contract.id] ?? const [];
    final inspections = graph.inspectionsByContract[contract.id] ?? const [];
    final document = graph.contractDocumentsByContract[contract.id];
    final lines = <String>[
      contract.contractNumber,
      messages.assistantVehicle((vehicle == null ? messages.assistantUnknown : _vehicleName(vehicle)).toString()),
      messages.assistantClient((client?.fullName ?? messages.assistantUnknown).toString()),
      messages.assistantStatus(status(contract.displayStatus)),
      messages.assistantDeparture((_shortDate(contract.startDate)).toString()),
      messages.assistantReturn((_shortDate(contract.expectedReturnDate)).toString()),
      messages.assistantTotal((contract.totalPrice.toStringAsFixed(2)).toString()),
      messages.assistantPaid((contract.amountPaid.toStringAsFixed(2)).toString()),
      messages.assistantBalance((contract.remainingAmount.toStringAsFixed(2)).toString()),
    ];
    if (chauffeur != null) lines.add(messages.assistantDriver((chauffeur.fullName).toString()));
    lines.add(messages.assistantPayments((payments.length).toString()));
    lines.add(messages.assistantInspections((inspections.length).toString()));
    if (document != null) {
      final recordedAt = document['recorded_at'] as String?;
      lines.add(recordedAt == null
          ? messages.assistantPendingSignature
          : messages.assistantSavedSignature);
    }
    return AssistantAnswer(
      text: lines.join('\n'),
      actions: [
        AssistantAction(label: messages.viewContracts, route: '/contracts')
      ],
    );
  }

  AssistantAnswer _answerForClient(
      ClientModel client, AssistantKnowledgeGraph graph) {
    final contracts = graph.contractsForClient(client.id!);
    final active = contracts.where((item) => item.status == 'active').length;
    final lines = <String>[
      client.fullName,
      messages.assistantId((client.cin).toString()),
      messages.assistantLicence((client.licenseNumber).toString()),
      messages.assistantPhone((client.phone).toString()),
    ];
    if (client.email?.isNotEmpty == true) lines.add(messages.assistantEmail((client.email).toString()));
    lines.add(messages.assistantContracts((contracts.length).toString(), (active).toString()));
    return AssistantAnswer(
      text: lines.join('\n'),
      actions: [
        AssistantAction(label: messages.viewClients, route: '/clients')
      ],
    );
  }

  AssistantAnswer _answerForChauffeur(
      ChauffeurModel chauffeur, AssistantKnowledgeGraph graph) {
    final contracts = graph.contractsForChauffeur(chauffeur.id!);
    return AssistantAnswer(
      text: messages.assistantDriverDetails((chauffeur.fullName).toString(), (chauffeur.cin).toString(), (chauffeur.licenseNumber).toString(), (chauffeur.phone).toString(), status(chauffeur.status), (chauffeur.hourlyRate.toStringAsFixed(2)).toString(), (contracts.length).toString()),
      actions: [
        AssistantAction(label: messages.viewDrivers, route: '/chauffeurs')
      ],
    );
  }

  AssistantAnswer _answerForVehicle(
    VehicleModel vehicle,
    String question,
    AssistantKnowledgeGraph graph,
  ) {
    if (_contains(question, [
      'contrat',
      'contract',
      'location',
      'rental',
      'loue',
      'rented',
      'retour',
      'return',
      'client',
      'who',
    ])) {
      final contracts = graph.contractsForVehicle(vehicle.id!);
      final active =
          contracts.where((item) => item.status == 'active').toList();
      if (active.isEmpty) {
        return AssistantAnswer(
          text: messages.assistantVehicleNoContract((_vehicleName(vehicle)).toString()),
          actions: [
            AssistantAction(label: messages.viewContracts, route: '/contracts')
          ],
        );
      }
      final contract = active.first;
      final client = graph.clients[contract.primaryDriverId];
      return AssistantAnswer(
        text: messages.assistantVehicleRental((_vehicleName(vehicle)).toString(), (contract.contractNumber).toString(), (_shortDate(contract.expectedReturnDate)).toString(), (contract.remainingAmount.toStringAsFixed(2)).toString(), (client?.fullName ?? messages.assistantUnknown).toString()),
        actions: [
          AssistantAction(label: messages.viewContract, route: '/contracts')
        ],
      );
    }
    if (_contains(question, [
      'assurance',
      'visite',
      'vignette',
      'vidange',
      'courroie',
      'chaine',
      'entretien', 'maintenance', 'صيانة',
    ])) {
      final warnings = _maintenanceWarnings([vehicle], question);
      return AssistantAnswer(
        text: warnings.isEmpty
            ? messages.assistantVehicleNoDeadline((_vehicleName(vehicle)).toString())
            : warnings.join('\n'),
        actions: [
          AssistantAction(label: messages.viewVehicle, route: '/vehicles')
        ],
      );
    }
    return AssistantAnswer(
      text: _vehicleDetails(vehicle),
      actions: [
        AssistantAction(label: messages.viewVehicle, route: '/vehicles')
      ],
    );
  }

  String _vehicleDetails(VehicleModel vehicle) {
    const statuses = {
      'available': 'Disponible',
      'rented': 'Loué',
      'maintenance': 'En entretien',
    };
    const transmissions = {'manual': 'Manuelle', 'automatic': 'Automatique'};
    const fuels = {
      'petrol': 'Essence',
      'diesel': 'Diesel',
      'hybrid': 'Hybride',
      'electric': 'Électrique',
      'lpg': 'GPL',
    };
    final details = StringBuffer()
      ..writeln(_vehicleName(vehicle))
      ..writeln(messages.assistantYear((vehicle.year).toString()))
      ..writeln(messages.assistantStatus(status(vehicle.status)))
      ..writeln(messages.assistantMileage((vehicle.currentMileage).toString()))
      ..writeln(messages.assistantFuel(tr(fuels[vehicle.fuelType] ?? vehicle.fuelType)))
      ..writeln(
          messages.assistantGearbox(tr(transmissions[vehicle.transmission] ?? vehicle.transmission)))
      ..writeln(messages.assistantFuelLevel((vehicle.fuelLevel).toString()))
      ..writeln(messages.assistantCondition(status(vehicle.conditionStatus)));
    if (vehicle.insuranceExpiryDate != null) {
      details
          .writeln(messages.assistantInsurance((_shortDate(vehicle.insuranceExpiryDate!)).toString()));
    }
    if (vehicle.technicalInspectionExpiryDate != null) {
      details.writeln(
          messages.assistantInspection((_shortDate(vehicle.technicalInspectionExpiryDate!)).toString()));
    }
    if (vehicle.vignetteDueDate != null) {
      details.writeln(messages.assistantTax((_shortDate(vehicle.vignetteDueDate!)).toString()));
    }
    return details.toString().trim();
  }

  List<String> _maintenanceWarnings(
      Iterable<VehicleModel> vehicles, String question) {
    final now = DateTime.now();
    final selected = <String>[];
    for (final vehicle in vehicles) {
      void addDate(String label, DateTime? date) {
        if (date == null) return;
        final days = date.difference(now).inDays;
        if (days <= 30) {
          selected.add(
              messages.assistantWarning((_vehicleName(vehicle)).toString(), tr(label == 'distribution' ? 'Courroie / chaîne' : '${label[0].toUpperCase()}${label.substring(1)}'), (days < 0 ? messages.assistantLateDays((-days).toString()) : messages.assistantInDays(days.toString())).toString()));
        }
      }

      final all = !_contains(question,
          ['assurance', 'visite', 'vignette', 'vidange', 'courroie', 'chaine']);
      if (all || _contains(question, ['assurance'])) {
        addDate('assurance', vehicle.insuranceExpiryDate);
      }
      if (all || _contains(question, ['visite'])) {
        addDate('visite technique', vehicle.technicalInspectionExpiryDate);
      }
      if (all || _contains(question, ['vignette'])) {
        addDate('vignette', vehicle.vignetteDueDate);
      }
      if (all || _contains(question, ['vidange'])) {
        addDate('vidange', vehicle.oilChangeDueDate);
      }
      if (all || _contains(question, ['courroie', 'chaine'])) {
        addDate('distribution', vehicle.distributionDueDate);
      }
    }
    return selected.take(8).toList();
  }

  static String _contractLines(List<ContractModel> contracts) => contracts
      .take(5)
      .map((item) =>
          '${item.contractNumber} (${item.remainingAmount.toStringAsFixed(2)} MAD)')
      .join(', ');

  static String _vehicleName(VehicleModel vehicle) =>
      '${vehicle.brand} ${vehicle.model} (${vehicle.registrationNumber})';

  static String _shortDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  static double _entityMatchScore(String question, String entity) {
    if (entity.isEmpty) return 0;
    if (question.contains(entity)) return 1;
    final questionWords =
        question.split(RegExp(r'[^a-z0-9]+')).where((word) => word.length >= 4);
    final entityWords =
        entity.split(RegExp(r'[^a-z0-9]+')).where((word) => word.length >= 4);
    var best = 0.0;
    for (final queryWord in questionWords) {
      for (final entityWord in entityWords) {
        final longest = queryWord.length > entityWord.length
            ? queryWord.length
            : entityWord.length;
        final score = 1 - (_levenshtein(queryWord, entityWord) / longest);
        if (score > best) best = score;
      }
    }
    return best;
  }

  static int _levenshtein(String first, String second) {
    var previous = List<int>.generate(second.length + 1, (index) => index);
    for (var row = 1; row <= first.length; row++) {
      final current = List<int>.filled(second.length + 1, 0);
      current[0] = row;
      for (var column = 1; column <= second.length; column++) {
        final replace = previous[column - 1] +
            (first[row - 1] == second[column - 1] ? 0 : 1);
        final insert = current[column - 1] + 1;
        final remove = previous[column] + 1;
        current[column] = [replace, insert, remove].reduce(
          (lowest, value) => value < lowest ? value : lowest,
        );
      }
      previous = current;
    }
    return previous.last;
  }

  static bool _contains(String value, List<String> terms) =>
      terms.any(value.contains);

  static bool _preservesEvidence(String answer, String facts) {
    final evidence = RegExp(r'CTR-[A-Z0-9-]+|\([^)]+\)|\b\d+(?:[.,]\d+)?\b')
        .allMatches(facts.toUpperCase())
        .map((match) => match.group(0)!)
        .where((token) => token.length > 1)
        .toSet();
    // General help has no database evidence. Returning the deterministic help
    // text is more useful than spending time on a small model's greeting.
    if (evidence.isEmpty) return false;
    final normalizedAnswer = answer.toUpperCase();
    return evidence.every(normalizedAnswer.contains);
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('ç', 'c');
}
