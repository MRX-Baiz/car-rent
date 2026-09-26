enum SearchResultKind { client, vehicle, contract }

class SearchResultItem {
  const SearchResultItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    this.status,
  });

  final SearchResultKind kind;
  final int id;
  final String title;
  final String subtitle;
  final String? status;
}

class AgencySearchResults {
  const AgencySearchResults({
    this.clients = const [],
    this.vehicles = const [],
    this.contracts = const [],
  });

  final List<SearchResultItem> clients;
  final List<SearchResultItem> vehicles;
  final List<SearchResultItem> contracts;

  bool get isEmpty => clients.isEmpty && vehicles.isEmpty && contracts.isEmpty;
}
