import 'dart:collection';

class PagedState<T> {
  PagedState({
    List<T> items = const [],
    this.nextOffset = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.totalCount,
  }) : items = UnmodifiableListView(items);

  final UnmodifiableListView<T> items;
  final int? nextOffset;
  final bool hasMore;
  final bool isLoadingMore;
  final int? totalCount;
}
