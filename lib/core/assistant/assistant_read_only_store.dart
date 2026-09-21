import '../../core/database/database_helper.dart';
import '../../data/models/chauffeur_model.dart';
import '../../data/models/client_model.dart';
import '../../data/models/contract_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/vehicle_model.dart';

/// Read-only, short-lived in-memory graph of the agency's business records.
/// Security data (PIN, licence key and settings) is deliberately excluded.
class AssistantReadOnlyStore {
  AssistantReadOnlyStore._();

  static final instance = AssistantReadOnlyStore._();

  AssistantKnowledgeGraph? _cached;
  DateTime? _cachedAt;
  static const _cacheLifetime = Duration(seconds: 20);

  Future<AssistantKnowledgeGraph> graph({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cached = _cached;
    if (!forceRefresh &&
        cached != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _cacheLifetime) {
      return cached;
    }

    final db = await DatabaseHelper.instance.openAssistantReadOnlyDatabase();
    try {
      final rows = await Future.wait([
        db.query('vehicles'),
        // Archived clients remain available for historical contracts and
        // direct lookup. The assistant never writes to this connection.
        db.query('clients'),
        db.query('chauffeurs'),
        db.query('contracts'),
        db.query('payments'),
        db.query('contract_inspections'),
        // Read document and photo metadata only. File paths and image bytes are
        // intentionally never copied into the assistant's prompt.
        db.query(
          'contract_documents',
          columns: ['contract_id', 'method', 'prepared_at', 'recorded_at'],
        ),
        db.query(
          'vehicle_photos',
          columns: ['id', 'vehicle_id', 'kind', 'note', 'created_at'],
        ),
        db.query(
          'inspection_photos',
          columns: ['id', 'inspection_id', 'kind', 'note', 'created_at'],
        ),
        db.query('vehicle_alert_history'),
      ]);
      final graph = AssistantKnowledgeGraph(
        vehicles: rows[0].map(VehicleModel.fromMap).toList(),
        clients: rows[1].map(ClientModel.fromMap).toList(),
        chauffeurs: rows[2].map(ChauffeurModel.fromMap).toList(),
        contracts: rows[3].map(ContractModel.fromMap).toList(),
        payments: rows[4].map(PaymentModel.fromMap).toList(),
        inspections: rows[5],
        contractDocuments: rows[6],
        vehiclePhotos: rows[7],
        inspectionPhotos: rows[8],
        vehicleAlertHistory: rows[9],
      );
      _cached = graph;
      _cachedAt = now;
      return graph;
    } finally {
      await db.close();
    }
  }

  void invalidate() {
    _cached = null;
    _cachedAt = null;
  }
}

class AssistantKnowledgeGraph {
  final Map<int, VehicleModel> vehicles;
  final Map<int, ClientModel> clients;
  final Map<int, ChauffeurModel> chauffeurs;
  final Map<int, ContractModel> contracts;
  final Map<int, List<ContractModel>> _contractsByVehicle;
  final Map<int, List<ContractModel>> _contractsByClient;
  final Map<int, List<ContractModel>> _contractsByChauffeur;
  final Map<int, List<PaymentModel>> paymentsByContract;
  final Map<int, List<Map<String, Object?>>> inspectionsByContract;
  final Map<int, Map<String, Object?>> contractDocumentsByContract;
  final Map<int, List<Map<String, Object?>>> vehiclePhotosByVehicle;
  final Map<int, List<Map<String, Object?>>> inspectionPhotosByInspection;
  final Map<int, List<Map<String, Object?>>> vehicleAlertHistoryByVehicle;

  AssistantKnowledgeGraph({
    required List<VehicleModel> vehicles,
    required List<ClientModel> clients,
    required List<ChauffeurModel> chauffeurs,
    required List<ContractModel> contracts,
    required List<PaymentModel> payments,
    required List<Map<String, Object?>> inspections,
    required List<Map<String, Object?>> contractDocuments,
    required List<Map<String, Object?>> vehiclePhotos,
    required List<Map<String, Object?>> inspectionPhotos,
    required List<Map<String, Object?>> vehicleAlertHistory,
  })  : vehicles = {
          for (final value in vehicles)
            if (value.id != null) value.id!: value,
        },
        clients = {
          for (final value in clients)
            if (value.id != null) value.id!: value,
        },
        chauffeurs = {
          for (final value in chauffeurs)
            if (value.id != null) value.id!: value,
        },
        contracts = {
          for (final value in contracts)
            if (value.id != null) value.id!: value,
        },
        _contractsByVehicle =
            _groupContracts(contracts, (item) => item.vehicleId),
        _contractsByClient = _groupContractsForClients(contracts),
        _contractsByChauffeur = _groupContracts(
          contracts.where((item) => item.chauffeurId != null),
          (item) => item.chauffeurId!,
        ),
        paymentsByContract = _groupPayments(payments),
        inspectionsByContract = _groupByInt(inspections, 'contract_id'),
        contractDocumentsByContract = {
          for (final value in contractDocuments)
            if (value['contract_id'] is int) value['contract_id'] as int: value,
        },
        vehiclePhotosByVehicle = _groupByInt(vehiclePhotos, 'vehicle_id'),
        inspectionPhotosByInspection =
            _groupByInt(inspectionPhotos, 'inspection_id'),
        vehicleAlertHistoryByVehicle =
            _groupByInt(vehicleAlertHistory, 'vehicle_id');

  List<ContractModel> contractsForVehicle(int id) =>
      List.unmodifiable(_contractsByVehicle[id] ?? const []);

  List<ContractModel> contractsForClient(int id) =>
      List.unmodifiable(_contractsByClient[id] ?? const []);

  List<ContractModel> contractsForChauffeur(int id) =>
      List.unmodifiable(_contractsByChauffeur[id] ?? const []);

  static Map<int, List<ContractModel>> _groupContracts(
    Iterable<ContractModel> values,
    int Function(ContractModel) idFor,
  ) {
    final result = <int, List<ContractModel>>{};
    for (final value in values) {
      result.putIfAbsent(idFor(value), () => []).add(value);
    }
    return result;
  }

  static Map<int, List<ContractModel>> _groupContractsForClients(
      Iterable<ContractModel> values) {
    final result = <int, List<ContractModel>>{};
    for (final value in values) {
      result.putIfAbsent(value.primaryDriverId, () => []).add(value);
      if (value.secondaryDriverId != null) {
        result.putIfAbsent(value.secondaryDriverId!, () => []).add(value);
      }
    }
    return result;
  }

  static Map<int, List<PaymentModel>> _groupPayments(
      Iterable<PaymentModel> values) {
    final result = <int, List<PaymentModel>>{};
    for (final value in values) {
      result.putIfAbsent(value.contractId, () => []).add(value);
    }
    return result;
  }

  static Map<int, List<Map<String, Object?>>> _groupByInt(
    Iterable<Map<String, Object?>> values,
    String key,
  ) {
    final result = <int, List<Map<String, Object?>>>{};
    for (final value in values) {
      final id = value[key] as int?;
      if (id != null) {
        result.putIfAbsent(id, () => []).add(value);
      }
    }
    return result;
  }
}
