import 'dart:collection';

import 'package:doctylia_app/core/pagination/page_request.dart';

class PageResult<T> {
  PageResult({
    required List<T> items,
    required this.hasMore,
    this.nextOffset,
    this.totalCount,
  }) : items = UnmodifiableListView(items);

  factory PageResult.fromLookahead({
    required List<T> rows,
    required PageRequest request,
    int? totalCount,
  }) {
    final hasMore = rows.length > request.limit;
    final visibleRows = hasMore ? rows.take(request.limit).toList() : rows;
    return PageResult(
      items: visibleRows,
      hasMore: hasMore,
      nextOffset: hasMore ? request.offset + request.limit : null,
      totalCount: totalCount,
    );
  }

  final UnmodifiableListView<T> items;
  final bool hasMore;
  final int? nextOffset;
  final int? totalCount;
}
