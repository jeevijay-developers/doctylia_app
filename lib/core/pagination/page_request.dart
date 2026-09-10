class PageRequest {
  const PageRequest({this.offset = 0, this.limit = defaultLimit})
    : assert(offset >= 0),
      assert(limit > 0 && limit <= maxLimit);

  static const defaultLimit = 20;
  static const maxLimit = 100;

  final int offset;
  final int limit;

  /// Supabase range is inclusive; this requests one look-ahead row.
  int get inclusiveRangeEnd => offset + limit;

  PageRequest next() => PageRequest(offset: offset + limit, limit: limit);
}
