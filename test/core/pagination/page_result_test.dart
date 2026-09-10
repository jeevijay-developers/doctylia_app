import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('look-ahead pagination', () {
    test('requests one extra inclusive Supabase row', () {
      const request = PageRequest(offset: 20, limit: 20);
      expect(request.inclusiveRangeEnd, 40);
      expect(request.next().offset, 40);
    });

    test('removes look-ahead row and exposes next offset', () {
      const request = PageRequest(offset: 0, limit: 2);
      final page = PageResult.fromLookahead(
        rows: const ['a', 'b', 'c'],
        request: request,
      );

      expect(page.items, ['a', 'b']);
      expect(page.hasMore, isTrue);
      expect(page.nextOffset, 2);
    });

    test('marks final page when no look-ahead row exists', () {
      const request = PageRequest(offset: 2, limit: 2);
      final page = PageResult.fromLookahead(
        rows: const ['c'],
        request: request,
      );

      expect(page.items, ['c']);
      expect(page.hasMore, isFalse);
      expect(page.nextOffset, isNull);
    });
  });
}
