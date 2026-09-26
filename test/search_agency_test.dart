import 'package:car_rent_manager/domain/entities/search_result.dart';
import 'package:car_rent_manager/domain/repositories/agency_search_repository.dart';
import 'package:car_rent_manager/domain/usecases/search_agency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search use case depends only on the agency search contract', () async {
    final search = SearchAgency(_FakeAgencySearchRepository());

    final results = await search('dacia');

    expect(results.vehicles.single.title, 'Dacia Logan');
    expect(results.clients, isEmpty);
  });
}

class _FakeAgencySearchRepository implements AgencySearchRepository {
  @override
  Future<AgencySearchResults> search(String query) async =>
      const AgencySearchResults(
        vehicles: [
          SearchResultItem(
            kind: SearchResultKind.vehicle,
            id: 1,
            title: 'Dacia Logan',
            subtitle: '123-A-45',
            status: 'available',
          ),
        ],
      );
}
