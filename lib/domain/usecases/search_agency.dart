import '../entities/search_result.dart';
import '../repositories/agency_search_repository.dart';

class SearchAgency {
  const SearchAgency(this._repository);

  final AgencySearchRepository _repository;

  Future<AgencySearchResults> call(String query) => _repository.search(query);
}
