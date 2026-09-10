import 'dart:async';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_empty_view.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/features/blog/domain/entities/blog_post.dart';
import 'package:doctylia_app/features/blog/presentation/providers/blog_providers.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_gate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const _blogCategories = [
  'General Health',
  'Heart Health',
  'Diabetes',
  'Skin Care',
  'Mental Health',
  'Nutrition',
  'Fitness',
  "Women's Health",
  "Children's Health",
  'Prevention',
];

InputDecoration _fieldDecoration(String label, {String? helperText}) =>
    InputDecoration(
      labelText: label,
      helperText: helperText,
      alignLabelWithHint: helperText != null,
      filled: true,
      fillColor: AppColors.primary.withOpacity(0.035),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
    );

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});
  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  Timer? _debounce;
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(blogPostsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showEditor(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Post'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => ref.read(blogPostsProvider.notifier).search(value),
                );
              },
              decoration: InputDecoration(
                hintText: 'Search posts or categories',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.primary.withOpacity(0.045),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const AppLoadingView(label: 'Loading blog posts'),
              error: (error, _) => AppErrorView(
                message: error is AppFailure
                    ? error.userMessage
                    : 'Could not load blog posts.',
                onRetry: () => ref.read(blogPostsProvider.notifier).refresh(),
              ),
              data: (page) => RefreshIndicator(
                onRefresh: () => ref.read(blogPostsProvider.notifier).refresh(),
                child: page.items.isEmpty
                    ? ListView(
                        children: const [
                          AppEmptyView(
                            icon: Icons.article_rounded,
                            title: 'No blog posts',
                            message:
                                'Write your first patient-friendly health article.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          96,
                        ),
                        itemCount: page.items.length + 1,
                        itemBuilder: (_, index) => index == page.items.length
                            ? PagedListFooter(
                                hasMore: page.hasMore,
                                onLoadMore: () => ref
                                    .read(blogPostsProvider.notifier)
                                    .loadMore(),
                              )
                            : _BlogCard(post: page.items[index]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogCard extends ConsumerWidget {
  const _BlogCard({required this.post});
  final BlogPost post;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = post.isPublished
        ? AppColors.success
        : AppColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  post.isPublished ? 'Published' : 'Draft',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              if (post.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    post.category!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            post.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (post.excerpt != null) ...[
            const SizedBox(height: 2),
            Text(
              post.excerpt!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.mutedText(context)),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            DateFormat('d MMM yyyy').format(post.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.subtleText(context),
            ),
          ),
          Divider(height: AppSpacing.lg, color: AppColors.border(context)),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                onPressed: () => _showEditor(context, ref, post),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                onPressed: () async {
                  final error = await ref
                      .read(blogPostsProvider.notifier)
                      .togglePublished(post.id);
                  if (context.mounted) {
                    _message(
                      context,
                      error ??
                          (post.isPublished
                              ? 'Post unpublished.'
                              : 'Post published.'),
                    );
                  }
                },
                icon: Icon(
                  post.isPublished
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18,
                ),
                label: Text(post.isPublished ? 'Unpublish' : 'Publish'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Delete post',
                onPressed: () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      title: const Text('Delete this post?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.destructive,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) {
                    final error = await ref
                        .read(blogPostsProvider.notifier)
                        .delete(post.id);
                    if (context.mounted) {
                      _message(context, error ?? 'Post deleted.');
                    }
                  }
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.destructive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showEditor(
  BuildContext context,
  WidgetRef ref,
  BlogPost? post,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BlogEditorSheet(post: post),
  );
}

class _AiWriter extends StatelessWidget {
  const _AiWriter({
    required this.topic,
    required this.generating,
    required this.generate,
    this.error,
  });

  final TextEditingController topic;
  final bool generating;
  final String? error;
  final VoidCallback generate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.aiPurple.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.aiPurple.withValues(alpha: .25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.aiPurple.withOpacity(0.16),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.aiPurple,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Text(
              'AI Blog Writer',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.aiPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: topic,
                enabled: !generating,
                onSubmitted: generating ? null : (_) => generate(),
                decoration: InputDecoration(
                  hintText: 'e.g. Tips for heart health',
                  filled: true,
                  fillColor: AppColors.aiPurple.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.aiPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onPressed: generating ? null : generate,
              child: Text(generating ? 'Writing...' : 'Generate'),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AppColors.destructive,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  error!,
                  style: const TextStyle(color: AppColors.destructive),
                ),
              ),
              TextButton(
                onPressed: generating ? null : generate,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _LockedAiWriter extends StatelessWidget {
  const _LockedAiWriter();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.aiPurple.withValues(alpha: .05),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.aiPurple.withValues(alpha: .2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.aiPurple.withOpacity(0.14),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AppColors.aiPurple,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: Text(
            'AI Blog Writer is available on Pro and Premium plans. Upgrade to generate patient-friendly drafts.',
          ),
        ),
      ],
    ),
  );
}

class _BlogEditorSheet extends ConsumerStatefulWidget {
  const _BlogEditorSheet({this.post});

  final BlogPost? post;

  @override
  ConsumerState<_BlogEditorSheet> createState() => _BlogEditorSheetState();
}

class _BlogEditorSheetState extends ConsumerState<_BlogEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _excerpt;
  late final TextEditingController _content;
  final _topic = TextEditingController();
  late String _category;
  late bool _published;
  String? _coverUrl;
  bool _generating = false;
  bool _uploading = false;
  bool _saving = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.post?.title);
    _excerpt = TextEditingController(text: widget.post?.excerpt);
    _content = TextEditingController(text: widget.post?.content);
    _category = widget.post?.category ?? 'General Health';
    _published = widget.post?.isPublished ?? false;
    _coverUrl = widget.post?.featuredImageUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _excerpt.dispose();
    _content.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_topic.text.trim().isEmpty) {
      setState(() => _aiError = 'Enter a topic for the article.');
      return;
    }
    setState(() {
      _generating = true;
      _aiError = null;
    });
    try {
      final draft = await ref
          .read(blogPostsProvider.notifier)
          .generate(_topic.text);
      if (!mounted) return;
      setState(() {
        _title.text = draft.title;
        _excerpt.text = draft.excerpt;
        _content.text = draft.content;
        _category = _blogCategories.contains(draft.category)
            ? draft.category
            : 'General Health';
        _topic.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _aiError = error is AppFailure
            ? error.userMessage
            : 'AI generation failed. Please check your connection and retry.';
      });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _uploadCover() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;
    final extension = file.extension?.toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    setState(() => _uploading = true);
    final result = await ref
        .read(blogPostsProvider.notifier)
        .uploadCover(
          BlogImageUpload(
            fileName: file.name,
            bytes: file.bytes!,
            mimeType: mimeType,
          ),
        );
    if (!mounted) return;
    setState(() => _uploading = false);
    result.fold(
      onSuccess: (url) {
        setState(() => _coverUrl = url);
        _message(context, 'Cover image uploaded.');
      },
      onFailure: (failure) => _message(context, failure.userMessage),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      _message(context, 'Title is required.');
      return;
    }
    setState(() => _saving = true);
    String? error;
    try {
      error = await ref
          .read(blogPostsProvider.notifier)
          .save(
            BlogPostDraft(
              id: widget.post?.id,
              title: _title.text,
              excerpt: _excerpt.text,
              content: _content.text,
              category: _category,
              featuredImageUrl: _coverUrl,
              isPublished: _published,
            ),
          );
    } catch (failure) {
      error = failure is AppFailure
          ? failure.userMessage
          : 'The post could not be saved. Please try again.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (error == null) {
      _message(
        context,
        widget.post == null ? 'Post created.' : 'Post updated.',
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.article_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.post == null ? 'New Blog Post' : 'Edit Post',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              FeatureGate(
                feature: FeatureKey.aiBlogWriter,
                lockedChild: const _LockedAiWriter(),
                child: _AiWriter(
                  topic: _topic,
                  generating: _generating,
                  error: _aiError,
                  generate: _generate,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _title,
                decoration: _fieldDecoration('Title *'),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_coverUrl != null && _coverUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.network(
                    _coverUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 90,
                      child: Center(child: Icon(Icons.broken_image_rounded)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: _uploading ? null : _uploadCover,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Replace cover'),
                    ),
                    TextButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => setState(() => _coverUrl = null),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Remove'),
                    ),
                  ],
                ),
              ] else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  onPressed: _uploading ? null : _uploadCover,
                  icon: _uploading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_rounded),
                  label: Text(
                    _uploading ? 'Uploading...' : 'Upload cover image',
                  ),
                ),
              Text(
                'JPG, PNG or WebP - up to 5 MB',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedText(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _excerpt,
                maxLines: 2,
                decoration: _fieldDecoration('Excerpt'),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: ValueKey(_category),
                initialValue: _category,
                decoration: _fieldDecoration('Category'),
                items: _blogCategories
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _RichContentEditor(controller: _content),
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.035),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primary,
                  title: const Text('Publish now'),
                  value: _published,
                  onChanged: (value) => setState(() => _published = value),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onPressed: _saving || _uploading ? null : _save,
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : widget.post == null
                        ? 'Create Post'
                        : 'Save Changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RichContentEditor extends StatelessWidget {
  const _RichContentEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Wrap(
          spacing: AppSpacing.xxs,
          children: [
            _ToolbarButton(
              tooltip: 'Heading',
              icon: Icons.title_rounded,
              onPressed: () => _insertMarkup(controller, '## ', ''),
            ),
            _ToolbarButton(
              tooltip: 'Bold',
              icon: Icons.format_bold_rounded,
              onPressed: () => _insertMarkup(controller, '**', '**'),
            ),
            _ToolbarButton(
              tooltip: 'Bulleted list',
              icon: Icons.format_list_bulleted_rounded,
              onPressed: () => _insertMarkup(controller, '- ', ''),
            ),
            _ToolbarButton(
              tooltip: 'Link',
              icon: Icons.link_rounded,
              onPressed: () => _insertMarkup(controller, '[', '](https://)'),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextField(
        controller: controller,
        minLines: 7,
        maxLines: 12,
        decoration: _fieldDecoration(
          'Rich content',
          helperText: 'HTML and Markdown formatting are preserved.',
        ),
      ),
    ],
  );
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        child: Icon(icon, size: 19, color: AppColors.primary),
      ),
    ),
  );
}

void _insertMarkup(
  TextEditingController controller,
  String prefix,
  String suffix,
) {
  final text = controller.text;
  final selection = controller.selection;
  final start = selection.isValid ? selection.start : text.length;
  final end = selection.isValid ? selection.end : text.length;
  final selected = text.substring(start, end);
  final replacement = '$prefix$selected$suffix';
  controller.value = TextEditingValue(
    text: text.replaceRange(start, end, replacement),
    selection: TextSelection.collapsed(
      offset: start + prefix.length + selected.length,
    ),
  );
}

void _message(BuildContext context, String value) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
