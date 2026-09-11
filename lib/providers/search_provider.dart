import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/search_service.dart';
import 'database_provider.dart';

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(ref.watch(databaseProvider));
});
