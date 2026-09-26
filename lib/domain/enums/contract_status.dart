enum ContractStatus {
  active,
  completed,
  late,
}

extension ContractStatusX on ContractStatus {
  String get dbValue {
    switch (this) {
      case ContractStatus.active:
        return 'active';
      case ContractStatus.completed:
        return 'completed';
      case ContractStatus.late:
        return 'late';
    }
  }

  static ContractStatus fromDb(String value) {
    switch (value) {
      case 'active':
        return ContractStatus.active;
      case 'completed':
        return ContractStatus.completed;
      case 'late':
        return ContractStatus.late;
      default:
        return ContractStatus.active;
    }
  }
}
