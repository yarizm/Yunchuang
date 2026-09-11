import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/search/search_page.dart';
import 'package:yunchuang/providers/search_provider.dart';
import 'package:yunchuang/services/search_service.dart';
import 'package:yunchuang/theme/app_theme.dart';
import 'package:yunchuang/widgets/glass_container.dart';

void main() {
  testWidgets('uses a stable search surface without background bleed',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SearchPage(),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final context = tester.element(find.byType(SearchPage));
    expect(scaffold.backgroundColor, stableSurfaceColor(context));
    expect(
      tester.widget<GlassContainer>(find.byType(GlassContainer)),
      isA<GlassContainer>()
          .having((container) => container.stable, 'stable', isTrue)
          .having((container) => container.blur, 'blur', 0),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('ignores stale search results that complete out of order',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final searchService = _QueuedSearchService(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchServiceProvider.overrideWithValue(searchService),
        ],
        child: const MaterialApp(home: SearchPage()),
      ),
    );

    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 350));
    expect(searchService.hasPending('old'), isTrue);

    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 350));
    expect(searchService.hasPending('new'), isTrue);

    searchService.completeWithBook('new', 'New result');
    await tester.pump();
    expect(find.text('New result'), findsOneWidget);

    searchService.completeWithBook('old', 'Old result');
    await tester.pump();
    expect(find.text('New result'), findsOneWidget);
    expect(find.text('Old result'), findsNothing);
  });
}

class _QueuedSearchService extends SearchService {
  final _pending = <String, Completer<List<SearchResult>>>{};

  _QueuedSearchService(super.database);

  @override
  Future<List<SearchResult>> search(String query) {
    final completer = Completer<List<SearchResult>>();
    _pending[query] = completer;
    return completer.future;
  }

  bool hasPending(String query) => _pending[query]?.isCompleted == false;

  void completeWithBook(String query, String title) {
    final completer = _pending[query];
    if (completer == null || completer.isCompleted) return;
    completer.complete([
      SearchResult(type: 'book', id: query.hashCode, title: title),
    ]);
  }
}
