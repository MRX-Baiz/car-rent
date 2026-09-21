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

  final _readOnly = AssistantReadOnlyStore.instance;
  final _gemma = GemmaRuntimeService.instance;

  /// Call this when opening the assistant after changing agency records.
  /// The next question rebuilds the snapshot through the read-only handle.
  void refreshAgencyData() => _readOnly.invalidate();

  Future<AssistantAnswer> answer(String rawQuestion) async {
    final question = rawQuestion.trim();
    if (question.isEmpty) {
      return const AssistantAnswer(text: 'Écrivez votre question.');
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
          text: await _gemma.answerGeneralQuestion(question),
          enhancedByModel: true,
        );
      }
      final enhanced = await _gemma.improveAnswer(
        question: question,
        facts: retrieved.text,
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

    if (_contains(question, ['vehicule', 'vehicle', 'voiture', 'cars'])) {
      final wantsAvailable = _contains(
        question,
        ['disponible', 'libre', 'available', 'free'],
      );
      final vehicles = graph.vehicles.values
          .where((vehicle) => !wantsAvailable || vehicle.status == 'available')
          .toList();
      if (vehicles.isEmpty) {
        return AssistantAnswer(
          text: wantsAvailable
              ? 'Aucun véhicule disponible actuellement.'
              : 'Aucun véhicule enregistré pour le moment.',
          actions: [
            AssistantAction(
              label:
                  wantsAvailable ? 'Voir les véhicules' : 'Ajouter un véhicule',
              route: wantsAvailable ? '/vehicles' : '/vehicles/add',
            ),
          ],
        );
      }
      final names = vehicles.take(12).map(_vehicleName).join(', ');
      final extra =
          vehicles.length > 12 ? ' et ${vehicles.length - 12} autre(s).' : '.';
      return AssistantAnswer(
        text: '${vehicles.length} véhicule(s) '
            '${wantsAvailable ? 'disponible(s)' : 'enregistré(s)'} : $names$extra',
        actions: const [
          AssistantAction(label: 'Voir les véhicules', route: '/vehicles')
        ],
      );
    }

    if (_contains(question, ['client', 'clients'])) {
      final clients = graph.clients.values.toList()
        ..sort((first, second) => first.fullName.compareTo(second.fullName));
      if (clients.isEmpty) {
        return const AssistantAnswer(
          text: 'Aucun client enregistré pour le moment.',
          actions: [
            AssistantAction(label: 'Ajouter un client', route: '/clients/add')
          ],
        );
      }
      final names = clients.take(12).map((item) => item.fullName).join(', ');
      final extra =
          clients.length > 12 ? ' et ${clients.length - 12} autre(s).' : '.';
      return AssistantAnswer(
        text: '${clients.length} client(s) enregistré(s) : $names$extra',
        actions: const [
          AssistantAction(label: 'Voir les clients', route: '/clients')
        ],
      );
    }

    if (_contains(question, ['chauffeur', 'chauffeurs', 'driver', 'drivers'])) {
      final chauffeurs = graph.chauffeurs.values.toList()
        ..sort((first, second) => first.fullName.compareTo(second.fullName));
      if (chauffeurs.isEmpty) {
        return const AssistantAnswer(
          text: 'Aucun chauffeur enregistré pour le moment.',
          actions: [
            AssistantAction(
                label: 'Ajouter un chauffeur', route: '/chauffeurs/add')
          ],
        );
      }
      final names = chauffeurs.take(12).map((item) => item.fullName).join(', ');
      final extra = chauffeurs.length > 12
          ? ' et ${chauffeurs.length - 12} autre(s).'
          : '.';
      return AssistantAnswer(
        text: '${chauffeurs.length} chauffeur(s) enregistré(s) : $names$extra',
        actions: const [
          AssistantAction(label: 'Voir les chauffeurs', route: '/chauffeurs')
        ],
      );
    }

    if (_contains(question, ['retard', 'en retard', 'late'])) {
      final contracts = graph.contracts.values
          .where((item) => item.isLate)
          .toList()
        ..sort((first, second) =>
            first.expectedReturnDate.compareTo(second.expectedReturnDate));
      if (contracts.isEmpty) {
        return const AssistantAnswer(
          text: 'Aucun contrat actif en retard.',
          actions: [
            AssistantAction(label: 'Voir les contrats', route: '/contracts')
          ],
        );
      }
      return AssistantAnswer(
        text:
            '${contracts.length} contrat(s) en retard : ${_contractLines(contracts)}',
        actions: const [
          AssistantAction(label: 'Voir les contrats', route: '/contracts')
        ],
      );
    }

    if (_contains(question, ['paiement', 'impaye', 'reste', 'solde'])) {
      final active = graph.contracts.values
          .where((item) => item.status == 'active')
          .toList();
      final unpaid =
          active.where((item) => item.remainingAmount > 0.01).toList();
      if (unpaid.isEmpty) {
        return const AssistantAnswer(
          text: 'Aucun solde restant sur les contrats actifs.',
          actions: [
            AssistantAction(label: 'Voir les contrats', route: '/contracts')
          ],
        );
      }
      final total =
          unpaid.fold<double>(0, (sum, item) => sum + item.remainingAmount);
      return AssistantAnswer(
        text:
            '${unpaid.length} paiement(s) en attente, pour ${total.toStringAsFixed(2)} MAD : ${_contractLines(unpaid)}',
        actions: const [
          AssistantAction(label: 'Voir les contrats', route: '/contracts')
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
      'entretien',
    ])) {
      final warnings = _maintenanceWarnings(graph.vehicles.values, question);
      if (warnings.isEmpty) {
        return const AssistantAnswer(
          text: 'Aucune échéance correspondante n’est renseignée ou proche.',
          actions: [
            AssistantAction(label: 'Voir les véhicules', route: '/vehicles')
          ],
        );
      }
      return AssistantAnswer(
        text: warnings.join('\n'),
        actions: const [
          AssistantAction(label: 'Voir les véhicules', route: '/vehicles')
        ],
      );
    }

    if (_contains(question, ['sauvegarde', 'backup', 'restaur'])) {
      return const AssistantAnswer(
        text:
            'Ouvrez Paramètres, puis Sauvegarde et restauration. La sauvegarde crée un ZIP avec les données et documents.',
        actions: [
          AssistantAction(label: 'Ouvrir les paramètres', route: '/settings')
        ],
      );
    }

    if (_contains(
        question, ['etat des lieux', 'inspection', 'depart', 'retour'])) {
      return const AssistantAnswer(
        text:
            'Ouvrez le contrat concerné. Vous pouvez remplir l’état des lieux de départ ou de retour avec kilométrage, carburant, photos et dégâts.',
        actions: [
          AssistantAction(label: 'Voir les contrats', route: '/contracts')
        ],
      );
    }

    return const AssistantAnswer(
      text:
          'Je peux aider avec les véhicules disponibles, contrats en retard, paiements en attente, alertes d’entretien, sauvegardes et états des lieux.',
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
      'Véhicule : ${vehicle == null ? 'inconnu' : _vehicleName(vehicle)}',
      'Client : ${client?.fullName ?? 'inconnu'}',
      'Statut : ${contract.status}',
      'Départ : ${_shortDate(contract.startDate)}',
      'Retour prévu : ${_shortDate(contract.expectedReturnDate)}',
      'Total : ${contract.totalPrice.toStringAsFixed(2)} MAD',
      'Payé : ${contract.amountPaid.toStringAsFixed(2)} MAD',
      'Reste : ${contract.remainingAmount.toStringAsFixed(2)} MAD',
    ];
    if (chauffeur != null) lines.add('Chauffeur : ${chauffeur.fullName}');
    lines.add('Paiements enregistrés : ${payments.length}');
    lines.add('États des lieux : ${inspections.length}');
    if (document != null) {
      final recordedAt = document['recorded_at'] as String?;
      lines.add(recordedAt == null
          ? 'Signature client : en attente'
          : 'Signature client : enregistrée');
    }
    return AssistantAnswer(
      text: lines.join('\n'),
      actions: const [
        AssistantAction(label: 'Voir les contrats', route: '/contracts')
      ],
    );
  }

  AssistantAnswer _answerForClient(
      ClientModel client, AssistantKnowledgeGraph graph) {
    final contracts = graph.contractsForClient(client.id!);
    final active = contracts.where((item) => item.status == 'active').length;
    final lines = <String>[
      client.fullName,
      'CIN : ${client.cin}',
      'Permis : ${client.licenseNumber}',
      'Téléphone : ${client.phone}',
    ];
    if (client.email?.isNotEmpty == true) lines.add('Email : ${client.email}');
    lines.add('Contrats : ${contracts.length}, dont $active actif(s).');
    return AssistantAnswer(
      text: lines.join('\n'),
      actions: const [
        AssistantAction(label: 'Voir les clients', route: '/clients')
      ],
    );
  }

  AssistantAnswer _answerForChauffeur(
      ChauffeurModel chauffeur, AssistantKnowledgeGraph graph) {
    final contracts = graph.contractsForChauffeur(chauffeur.id!);
    return AssistantAnswer(
      text: '${chauffeur.fullName}\n'
          'CIN : ${chauffeur.cin}\n'
          'Permis : ${chauffeur.licenseNumber}\n'
          'Téléphone : ${chauffeur.phone}\n'
          'Statut : ${chauffeur.status}\n'
          'Prix : ${chauffeur.hourlyRate.toStringAsFixed(2)} MAD/heure\n'
          'Contrats liés : ${contracts.length}',
      actions: const [
        AssistantAction(label: 'Voir les chauffeurs', route: '/chauffeurs')
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
          text: '${_vehicleName(vehicle)} n’a pas de contrat actif.',
          actions: const [
            AssistantAction(label: 'Voir les contrats', route: '/contracts')
          ],
        );
      }
      final contract = active.first;
      final client = graph.clients[contract.primaryDriverId];
      return AssistantAnswer(
        text: '${_vehicleName(vehicle)} est loué avec le contrat '
            '${contract.contractNumber}. Retour prévu : '
            '${_shortDate(contract.expectedReturnDate)}. Reste à encaisser : '
            '${contract.remainingAmount.toStringAsFixed(2)} MAD. '
            'Client : ${client?.fullName ?? 'inconnu'}.',
        actions: const [
          AssistantAction(label: 'Voir le contrat', route: '/contracts')
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
      'entretien',
    ])) {
      final warnings = _maintenanceWarnings([vehicle], question);
      return AssistantAnswer(
        text: warnings.isEmpty
            ? '${_vehicleName(vehicle)} : aucune échéance proche renseignée.'
            : warnings.join('\n'),
        actions: const [
          AssistantAction(label: 'Voir le véhicule', route: '/vehicles')
        ],
      );
    }
    return AssistantAnswer(
      text: _vehicleDetails(vehicle),
      actions: const [
        AssistantAction(label: 'Voir le véhicule', route: '/vehicles')
      ],
    );
  }

  static String _vehicleDetails(VehicleModel vehicle) {
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
      ..writeln('Année : ${vehicle.year}')
      ..writeln('Statut : ${statuses[vehicle.status] ?? vehicle.status}')
      ..writeln('Kilométrage : ${vehicle.currentMileage} km')
      ..writeln('Carburant : ${fuels[vehicle.fuelType] ?? vehicle.fuelType}')
      ..writeln(
          'Boîte : ${transmissions[vehicle.transmission] ?? vehicle.transmission}')
      ..writeln('Niveau carburant : ${vehicle.fuelLevel}%')
      ..writeln('État : ${vehicle.conditionStatus}');
    if (vehicle.insuranceExpiryDate != null) {
      details
          .writeln('Assurance : ${_shortDate(vehicle.insuranceExpiryDate!)}');
    }
    if (vehicle.technicalInspectionExpiryDate != null) {
      details.writeln(
          'Visite technique : ${_shortDate(vehicle.technicalInspectionExpiryDate!)}');
    }
    if (vehicle.vignetteDueDate != null) {
      details.writeln('Vignette : ${_shortDate(vehicle.vignetteDueDate!)}');
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
              '${_vehicleName(vehicle)} — $label ${days < 0 ? 'en retard de ${-days} j' : 'dans $days j'}');
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
