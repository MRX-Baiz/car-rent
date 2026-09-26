import '../entities/search_result.dart';

abstract interface class AgencySearchRepository {
  Future<AgencySearchResults> search(String query);
}
