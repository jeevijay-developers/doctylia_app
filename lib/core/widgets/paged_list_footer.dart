import 'dart:async';

import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

class PagedListFooter extends StatefulWidget {
  const PagedListFooter({
    required this.hasMore,
    required this.onLoadMore,
    this.isLoading = false,
    super.key,
  });
  final bool hasMore;
  final bool isLoading;
  final FutureOr<void> Function() onLoadMore;

  @override
  State<PagedListFooter> createState() => _PagedListFooterState();
}

class _PagedListFooterState extends State<PagedListFooter> {
  bool _loading = false;

  Future<void> _loadMore() async {
    if (_loading || widget.isLoading || !widget.hasMore) return;
    setState(() => _loading = true);
    try {
      await widget.onLoadMore();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.isLoading || _loading;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: widget.hasMore
            ? OutlinedButton(
                onPressed: loading ? null : _loadMore,
                child: Text(loading ? 'Loading…' : 'Load more'),
              )
            : Text(
                'You have reached the end',
                style: Theme.of(context).textTheme.bodySmall,
              ),
      ),
    );
  }
}
