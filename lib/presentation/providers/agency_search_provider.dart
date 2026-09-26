import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/agency_search_repository.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/agency_search_repository.dart';
import '../../domain/usecases/search_agency.dart';

final agencySearchRepositoryProvider = Provider<AgencySearchRepository>((ref) {
  return SqliteAgencySearchRepository.instance;
});

final searchAgencyProvider = Provider<SearchAgency>((ref) {
  return SearchAgency(ref.watch(agencySearchRepositoryProvider));
});

final agencySearchResultsProvider =
    FutureProvider.autoDispose.family<AgencySearchResults, String>(
  (ref, query) => ref.watch(searchAgencyProvider)(query),
);
