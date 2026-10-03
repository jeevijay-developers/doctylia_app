import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/features/website/domain/entities/website_models.dart';
import 'package:doctylia_app/features/website/presentation/providers/website_providers.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_gate.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

// Theme-neutral field chrome: these helpers have no BuildContext, so they use
// translucent colours that read correctly on both light and dark cards (a
// near-white fill made typed text invisible in dark mode).
final _kFieldFill = AppColors.primary.withValues(alpha: 0.05);
const _kHairline = Color(0x338A9BB5);

abstract final class _WebsiteType {
  static const sectionTitle = 14.0;
  static const subheading = 12.0;
  static const body = 12.0;
  static const label = 10.0;
  static const caption = 9.0;
}

class MyWebsiteScreen extends ConsumerStatefulWidget {
  const MyWebsiteScreen({super.key});
  @override
  ConsumerState<MyWebsiteScreen> createState() => _MyWebsiteScreenState();
}

class _MyWebsiteScreenState extends ConsumerState<MyWebsiteScreen> {
  final saving = <String>{};
  final sectionControllers = <String, ExpansibleController>{};

  @override
  void dispose() {
    for (final controller in sectionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(websiteProvider);
    final readOnly =
        ref.watch(trialStatusProvider).accessLevel == TrialAccessLevel.grace;
    return state.when(
      loading: () => const AppLoadingView(label: 'Loading website editor'),
      error: (error, _) => AppErrorView(
        message: error is AppFailure
            ? error.userMessage
            : 'Could not load website.',
        onRetry: () => ref.read(websiteProvider.notifier).refresh(),
      ),
      data: (snapshot) => Scaffold(
        body: RefreshIndicator(
          onRefresh: () => ref.read(websiteProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              96,
            ),
            children: [
              _PreviewCard(settings: snapshot.settings),
              const SizedBox(height: AppSpacing.sm),
              if (readOnly) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.lock_clock_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Your account is in grace mode. Website settings are read-only.',
                          style: TextStyle(fontSize: _WebsiteType.body),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              _section(
                'hero',
                'Hero Banner',
                Icons.auto_awesome_rounded,
                readOnly,
                _HeroEditor(
                  snapshot: snapshot,
                  readOnly: readOnly,
                  upload: _uploadHero,
                ),
              ),
              _section(
                'stats',
                'Quick Stats',
                Icons.query_stats_rounded,
                readOnly,
                _QuickStatsEditor(snapshot: snapshot, readOnly: readOnly),
              ),
              _section(
                'about',
                'About / Doctor Profile',
                Icons.person_rounded,
                readOnly,
                _ClinicEditor(
                  snapshot: snapshot,
                  readOnly: readOnly,
                  about: true,
                ),
              ),
              _section(
                'services',
                'Services',
                Icons.medical_services_rounded,
                readOnly,
                _ServicesEditor(snapshot: snapshot, readOnly: readOnly),
              ),
              _section(
                'gallery',
                'Gallery',
                Icons.photo_library_rounded,
                readOnly,
                _GalleryEditor(
                  snapshot: snapshot,
                  readOnly: readOnly,
                  upload: _uploadGallery,
                  message: _message,
                ),
              ),
              _section(
                'hours',
                'Working Hours',
                Icons.schedule_rounded,
                readOnly,
                _HoursEditor(snapshot: snapshot, readOnly: readOnly),
              ),
              _section(
                'booking',
                'Booking Settings',
                Icons.event_available_rounded,
                readOnly,
                _BookingEditor(snapshot: snapshot, readOnly: readOnly),
              ),
              FeatureGate(
                feature: FeatureKey.onlineConsultation,
                lockedChild: const _LockedOnline(),
                child: _section(
                  'online',
                  'Online Consultation',
                  Icons.video_call_rounded,
                  readOnly,
                  _OnlineEditor(snapshot: snapshot, readOnly: readOnly),
                ),
              ),
              _section(
                'reviews',
                'Reviews',
                Icons.star_rounded,
                readOnly,
                _ReviewsEditor(
                  snapshot: snapshot,
                  readOnly: readOnly,
                  message: _message,
                ),
              ),
              _section(
                'blog',
                'Blog Visibility',
                Icons.article_rounded,
                readOnly,
                _BlogEditor(snapshot: snapshot, readOnly: readOnly),
              ),
              _section(
                'clinic',
                'Clinic Details',
                Icons.local_hospital_rounded,
                readOnly,
                _ClinicEditor(
                  snapshot: snapshot,
                  readOnly: readOnly,
                  about: false,
                ),
              ),
              _section(
                'contact',
                'Website & WhatsApp',
                Icons.chat_rounded,
                readOnly,
                _ContactEditor(snapshot: snapshot, readOnly: readOnly),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(
    String key,
    String title,
    IconData icon,
    bool readOnly,
    Widget child,
  ) => _EditorCard(
    controller: sectionControllers.putIfAbsent(key, ExpansibleController.new),
    title: title,
    icon: icon,
    saving: saving.contains(key),
    onSave: readOnly ? null : () => _save(key),
    onExpansionChanged: (expanded) {
      if (!expanded) return;
      for (final entry in sectionControllers.entries) {
        if (entry.key != key && entry.value.isExpanded) {
          entry.value.collapse();
        }
      }
    },
    child: child,
  );

  Future<void> _save(String key) async {
    setState(() => saving.add(key));
    final error = await ref.read(websiteProvider.notifier).save();
    if (!mounted) return;
    setState(() => saving.remove(key));
    _message(error ?? 'Changes saved.');
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _uploadHero() async {
    final file = await _pickImage();
    if (file == null) return;
    final error = await ref.read(websiteProvider.notifier).uploadHero(file);
    if (mounted) {
      _message(error ?? 'Hero photo uploaded. Save Hero Banner to publish it.');
    }
  }

  Future<void> _uploadGallery() async {
    final file = await _pickImage();
    if (file == null) return;
    final error = await ref.read(websiteProvider.notifier).uploadGallery(file);
    if (mounted) _message(error ?? 'Gallery photo uploaded.');
  }

  Future<WebsiteImageUpload?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return null;
    final extension = file.extension?.toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => null,
    };
    return WebsiteImageUpload(
      fileName: file.name,
      bytes: file.bytes!,
      mimeType: mimeType,
    );
  }
}

class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({required this.settings});
  final WebsiteSettings settings;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withOpacity(0.1),
          AppColors.primary.withOpacity(0.02),
        ],
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.14),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(Icons.language_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your public website',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                settings.slug.isEmpty
                    ? 'Complete your profile slug first'
                    : 'doctylia.in/dr/${settings.slug}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _WebsiteType.body,
                  color: AppColors.onSurface(context).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: settings.slug.isEmpty
              ? null
              : () => ref
                    .read(externalLinkServiceProvider)
                    .open(Uri.parse('https://doctylia.in/dr/${settings.slug}')),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.controller,
    required this.title,
    required this.icon,
    required this.child,
    required this.saving,
    required this.onExpansionChanged,
    this.onSave,
  });
  final ExpansibleController controller;
  final String title;
  final IconData icon;
  final Widget child;
  final bool saving;
  final ValueChanged<bool> onExpansionChanged;
  final VoidCallback? onSave;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border(context)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1D4ED8).withValues(alpha: 0.035),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        controller: controller,
        onExpansionChanged: onExpansionChanged,
        initiallyExpanded: title == 'Hero Banner',
        minTileHeight: 66,
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.mutedText(context),
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 3,
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(icon, size: 19, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: _WebsiteType.sectionTitle,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          _editorSubtitle(title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.mutedText(context),
            fontSize: _WebsiteType.label,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(height: 1, color: AppColors.border(context)),
                const SizedBox(height: AppSpacing.md),
                DefaultTextStyle.merge(
                  style: TextStyle(
                    color: AppColors.onSurface(context),
                    fontSize: _WebsiteType.body,
                  ),
                  child: ListTileTheme(
                    data: ListTileThemeData(
                      titleTextStyle: TextStyle(
                        color: AppColors.onSurface(context),
                        fontSize: _WebsiteType.body,
                        fontWeight: FontWeight.w600,
                      ),
                      subtitleTextStyle: TextStyle(
                        color: AppColors.mutedText(context),
                        fontSize: _WebsiteType.label,
                      ),
                    ),
                    child: child,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: _WebsiteType.body,
                      fontWeight: FontWeight.w700,
                    ),
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.35,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(saving ? 'Saving...' : 'Save $title'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _editorSubtitle(String title) => switch (title) {
  'Hero Banner' => 'Public Doctor Profile Header',
  'Quick Stats' => 'Practice highlights and key numbers',
  'About / Doctor Profile' => 'Credentials, experience and introduction',
  'Services' => 'Consultations available for booking',
  'Gallery' => 'Clinic and practice photographs',
  'Working Hours' => 'Weekly clinic availability',
  'Booking Settings' => 'Appointment rules and confirmations',
  'Online Consultation' => 'Video visit options and payment',
  'Reviews' => 'Testimonials shown on your website',
  'Blog Visibility' => 'Control published health articles',
  'Clinic Details' => 'Address and public contact information',
  'Website & WhatsApp' => 'Search, social and messaging settings',
  _ => 'Public website settings',
};

class _HeroEditor extends ConsumerWidget {
  const _HeroEditor({
    required this.snapshot,
    required this.readOnly,
    required this.upload,
  });
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  final VoidCallback upload;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot.settings;
    void set(WebsiteSettings value) =>
        ref.read(websiteProvider.notifier).updateSettings(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroPortraitCard(snapshot: snapshot),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primary50,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                onPressed: readOnly ? null : upload,
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: Text(
                  s.heroPhotoUrl == null ? 'Upload photo' : 'Change photo',
                  style: const TextStyle(fontSize: _WebsiteType.body),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(96, 42),
                foregroundColor: AppColors.onSurface(context),
                side: BorderSide(color: AppColors.border(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onPressed: readOnly || s.heroPhotoUrl == null
                  ? null
                  : () => set(s.copyWith(clearHeroPhoto: true)),
              child: const Text(
                'Use profile',
                style: TextStyle(fontSize: _WebsiteType.body),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: const Text(
                      'Main Headlines & Messaging',
                      style: TextStyle(
                        fontSize: _WebsiteType.subheading,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'Auto-formatted',
                    style: TextStyle(
                      color: AppColors.subtleText(context),
                      fontSize: _WebsiteType.label,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _HeroTextField(
                label: 'HEADLINE - LINE 1',
                value: s.heroHeadlineLine1,
                readOnly: readOnly,
                onChanged: (v) => set(s.copyWith(heroHeadlineLine1: v)),
                trailingIcon: Icons.edit_outlined,
              ),
              _HeroTextField(
                label: 'HEADLINE - LINE 2',
                value: s.heroHeadlineLine2,
                readOnly: readOnly,
                onChanged: (v) => set(s.copyWith(heroHeadlineLine2: v)),
              ),
              _HeroTextField(
                label: 'DOCTOR SUBTEXT / DESCRIPTION',
                value: s.heroDescription,
                readOnly: readOnly,
                onChanged: (v) => set(s.copyWith(heroDescription: v)),
                maxLines: 3,
                maxLength: 140,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const _HeroSubsectionTitle(
          title: 'Hero actions & details',
          subtitle: 'Labels, badge and visual theme',
        ),
        _HeroActionsEditor(settings: s, readOnly: readOnly, onChanged: set),
      ],
    );
  }
}

class _HeroPortraitCard extends StatelessWidget {
  const _HeroPortraitCard({required this.snapshot});

  final WebsiteSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final settings = snapshot.settings;
    final clinic = snapshot.clinic;
    final rawName = clinic?.fullName.trim() ?? '';
    final doctorName = rawName.isEmpty
        ? 'Doctor Profile'
        : rawName.toLowerCase().startsWith('dr')
        ? rawName
        : 'Dr. $rawName';
    final specialization = clinic?.specialization.trim();
    final isLive = settings.slug.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context, alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'VISUAL PORTRAIT',
                  style: TextStyle(
                    color: AppColors.mutedText(context),
                    fontSize: _WebsiteType.label,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.35,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLive ? 'Live On Profile' : 'Draft Preview',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: _WebsiteType.caption,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: CustomPaint(
              painter: const _PortraitGridPainter(),
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 112,
                      height: 132,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(60),
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.92),
                          width: 2,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeroPortrait(photoUrl: settings.heroPhotoUrl),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 56),
                          child: Text(
                            doctorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: _WebsiteType.body,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          specialization?.isNotEmpty == true
                              ? specialization!
                              : 'Medical Professional',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: _WebsiteType.label,
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textDark.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              size: 10,
                              color: AppColors.teal,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Preview 1:1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _WebsiteType.caption,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPortrait extends StatelessWidget {
  const _HeroPortrait({this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_rounded,
        color: AppColors.primary,
        size: 28,
      ),
    );

    if (photoUrl == null || photoUrl!.trim().isEmpty) return fallback();
    return ClipOval(
      child: Image.network(
        photoUrl!,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
}

class _PortraitGridPainter extends CustomPainter {
  const _PortraitGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary.withValues(alpha: 0.09);
    for (double y = 9; y < size.height; y += 12) {
      for (double x = 9; x < size.width; x += 12) {
        canvas.drawCircle(Offset(x, y), 0.65, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroTextField extends StatelessWidget {
  const _HeroTextField({
    required this.label,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.trailingIcon,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final String value;
  final bool readOnly;
  final ValueChanged<String> onChanged;
  final IconData? trailingIcon;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.mutedText(context),
                  fontSize: _WebsiteType.label,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (maxLength != null)
              Text(
                '${value.length.clamp(0, maxLength!)}/$maxLength',
                style: TextStyle(
                  color: AppColors.subtleText(context),
                  fontSize: _WebsiteType.caption,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        TextFormField(
          initialValue: value,
          enabled: !readOnly,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(
            fontSize: _WebsiteType.body,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.secondarySurface(context),
            suffixIcon: trailingIcon == null
                ? null
                : Icon(
                    trailingIcon,
                    size: 15,
                    color: AppColors.subtleText(context),
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 11,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _HeroSubsectionTitle extends StatelessWidget {
  const _HeroSubsectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 2, 2, AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: _WebsiteType.subheading,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.subtleText(context),
            fontSize: _WebsiteType.label,
          ),
        ),
      ],
    ),
  );
}

class _HeroActionsEditor extends StatelessWidget {
  const _HeroActionsEditor({
    required this.settings,
    required this.readOnly,
    required this.onChanged,
  });

  final WebsiteSettings settings;
  final bool readOnly;
  final ValueChanged<WebsiteSettings> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: _kHairline),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HeroGroupHeader(
          icon: Icons.touch_app_rounded,
          title: 'PROFILE ACTIONS',
          subtitle: 'Labels shown on your public hero banner',
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _HeroActionField(
                label: 'LOCATION',
                icon: Icons.location_on_outlined,
                value: settings.heroLocationLabel,
                readOnly: readOnly,
                onChanged: (value) =>
                    onChanged(settings.copyWith(heroLocationLabel: value)),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _HeroActionField(
                label: 'HOURS',
                icon: Icons.schedule_rounded,
                value: settings.heroHoursLabel,
                readOnly: readOnly,
                onChanged: (value) =>
                    onChanged(settings.copyWith(heroHoursLabel: value)),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _HeroActionField(
                label: 'PRIMARY ACTION',
                icon: Icons.calendar_month_outlined,
                value: settings.heroPrimaryButtonLabel,
                readOnly: readOnly,
                onChanged: (value) =>
                    onChanged(settings.copyWith(heroPrimaryButtonLabel: value)),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _HeroActionField(
                label: 'CALL ACTION',
                icon: Icons.call_outlined,
                value: settings.heroSecondaryButtonLabel,
                readOnly: readOnly,
                onChanged: (value) => onChanged(
                  settings.copyWith(heroSecondaryButtonLabel: value),
                ),
              ),
            ),
          ],
        ),
        _HeroActionField(
          label: 'DIRECTIONS ACTION',
          icon: Icons.directions_outlined,
          value: settings.heroDirectionsLabel,
          readOnly: readOnly,
          onChanged: (value) =>
              onChanged(settings.copyWith(heroDirectionsLabel: value)),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary50.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 19,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Experience badge',
                          style: TextStyle(
                            fontSize: _WebsiteType.subheading,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Show a trust badge on your portrait',
                          style: TextStyle(
                            color: AppColors.mutedText(context),
                            fontSize: _WebsiteType.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.showHeroStatBadge,
                    activeThumbColor: AppColors.primary,
                    onChanged: readOnly
                        ? null
                        : (value) => onChanged(
                            settings.copyWith(showHeroStatBadge: value),
                          ),
                  ),
                ],
              ),
              if (settings.showHeroStatBadge) ...[
                const SizedBox(height: AppSpacing.xs),
                _HeroActionField(
                  label: 'BADGE TEXT',
                  icon: Icons.short_text_rounded,
                  value: settings.heroStatText,
                  readOnly: readOnly,
                  onChanged: (value) =>
                      onChanged(settings.copyWith(heroStatText: value)),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _statIcons.contains(settings.heroStatIcon)
                      ? settings.heroStatIcon
                      : 'Star',
                  isExpanded: true,
                  style: TextStyle(
                    color: AppColors.onSurface(context),
                    fontSize: _WebsiteType.body,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _heroActionDecoration(
                    label: 'BADGE ICON',
                    icon: Icons.auto_awesome_rounded,
                  ),
                  items: _statIcons
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: readOnly
                      ? null
                      : (value) =>
                            onChanged(settings.copyWith(heroStatIcon: value)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _HeroGroupHeader(
          icon: Icons.palette_outlined,
          title: 'COLOR THEME',
          subtitle: 'Choose the accent used across your public profile',
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final theme in const [
              ('royal', 'Royal', AppColors.primary),
              ('teal', 'Teal', AppColors.teal),
              ('violet', 'Violet', AppColors.aiPurple),
            ]) ...[
              Expanded(
                child: _ThemeChoice(
                  label: theme.$2,
                  color: theme.$3,
                  selected: settings.theme == theme.$1,
                  onTap: readOnly
                      ? null
                      : () => onChanged(settings.copyWith(theme: theme.$1)),
                ),
              ),
              if (theme.$1 != 'violet') const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
      ],
    ),
  );
}

class _HeroGroupHeader extends StatelessWidget {
  const _HeroGroupHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.onSurface(context),
                fontSize: _WebsiteType.label,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.35,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.subtleText(context),
                fontSize: _WebsiteType.label,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _HeroActionField extends StatelessWidget {
  const _HeroActionField({
    required this.label,
    required this.icon,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: TextFormField(
      initialValue: value,
      enabled: !readOnly,
      style: const TextStyle(
        fontSize: _WebsiteType.body,
        fontWeight: FontWeight.w600,
      ),
      decoration: _heroActionDecoration(label: label, icon: icon),
      onChanged: onChanged,
    ),
  );
}

InputDecoration _heroActionDecoration({
  required String label,
  required IconData icon,
}) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(
    fontSize: _WebsiteType.label,
    fontWeight: FontWeight.w700,
  ),
  prefixIcon: Icon(icon, size: 16, color: AppColors.primary),
  prefixIconConstraints: const BoxConstraints(minWidth: 37),
  filled: true,
  fillColor: _kFieldFill,
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: BorderSide(color: _kHairline),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: const BorderSide(color: AppColors.primary),
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: BorderSide(color: _kHairline),
  ),
);

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.09) : _kFieldFill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: selected ? color : _kHairline,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? color : AppColors.mutedText(context),
                fontSize: _WebsiteType.label,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 3),
            Icon(Icons.check_circle_rounded, size: 13, color: color),
          ],
        ],
      ),
    ),
  );
}

const _statIcons = [
  'Users',
  'Award',
  'ThumbsUp',
  'Headset',
  'Heart',
  'Activity',
  'Star',
  'ShieldCheck',
  'Clock',
  'Stethoscope',
  'Building',
  'Smile',
  'Zap',
  'CheckCircle',
];

class _QuickStatsEditor extends ConsumerWidget {
  const _QuickStatsEditor({required this.snapshot, required this.readOnly});
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot.settings;
    void set(List<WebsiteQuickStat> rows) => ref
        .read(websiteProvider.notifier)
        .updateSettings(s.copyWith(quickStats: rows));
    return Column(
      children: [
        _switch(
          'Show quick stats',
          s.showQuickStats,
          readOnly
              ? null
              : (v) => ref
                    .read(websiteProvider.notifier)
                    .updateSettings(s.copyWith(showQuickStats: v)),
        ),
        for (final stat in s.quickStats)
          Container(
            // Keyed so each row's text fields stay bound to their stat when
            // another stat is deleted (initialValue fields keep their state).
            key: ValueKey('quick-stat-${stat.id}'),
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.03),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stat.id == 'experience'
                            ? 'Experience stat'
                            : stat.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Switch(
                      value: stat.active,
                      activeThumbColor: AppColors.primary,
                      onChanged: readOnly
                          ? null
                          : (v) => set([
                              for (final row in s.quickStats)
                                if (row.id == stat.id)
                                  row.copyWith(active: v)
                                else
                                  row,
                            ]),
                    ),
                    IconButton(
                      onPressed: readOnly
                          ? null
                          : () => set(
                              s.quickStats
                                  .where((row) => row.id != stat.id)
                                  .toList(),
                            ),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.destructive,
                      ),
                    ),
                  ],
                ),
                _text(
                  'Label',
                  stat.label,
                  readOnly,
                  (v) => set([
                    for (final row in s.quickStats)
                      if (row.id == stat.id) row.copyWith(label: v) else row,
                  ]),
                ),
                _text(
                  'Value',
                  stat.value,
                  readOnly,
                  (v) => set([
                    for (final row in s.quickStats)
                      if (row.id == stat.id) row.copyWith(value: v) else row,
                  ]),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _statIcons.contains(stat.icon)
                      ? stat.icon
                      : 'Users',
                  style: TextStyle(
                    color: AppColors.onSurface(context),
                    fontSize: _WebsiteType.body,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _fieldDecoration('Icon'),
                  items: _statIcons
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: readOnly
                      ? null
                      : (v) => set([
                          for (final row in s.quickStats)
                            if (row.id == stat.id)
                              row.copyWith(icon: v)
                            else
                              row,
                        ]),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
            onPressed: readOnly
                ? null
                : () => set([
                    ...s.quickStats,
                    WebsiteQuickStat(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      label: 'New Stat',
                      value: '100+',
                      icon: 'Award',
                      active: true,
                    ),
                  ]),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add quick stat'),
          ),
        ),
      ],
    );
  }
}

class _ClinicEditor extends ConsumerWidget {
  const _ClinicEditor({
    required this.snapshot,
    required this.readOnly,
    required this.about,
  });
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  final bool about;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = snapshot.clinic;
    final s = snapshot.settings;
    if (p == null) return const Text('Clinic profile is unavailable.');
    void set(WebsiteClinic value) =>
        ref.read(websiteProvider.notifier).updateClinic(value);
    return Column(
      children: [
        _switch(
          about ? 'Show about section' : 'Show clinic details',
          about ? s.showAbout : s.showClinicDetails,
          readOnly
              ? null
              : (v) => ref
                    .read(websiteProvider.notifier)
                    .updateSettings(
                      about
                          ? s.copyWith(showAbout: v)
                          : s.copyWith(showClinicDetails: v),
                    ),
        ),
        if (about) ...[
          _text(
            'Doctor name *',
            p.fullName,
            readOnly,
            (v) => set(p.copyWith(fullName: v)),
          ),
          _text(
            'Specialization *',
            p.specialization,
            readOnly,
            (v) => set(p.copyWith(specialization: v)),
          ),
          _text(
            'Qualifications',
            p.qualifications,
            readOnly,
            (v) => set(p.copyWith(qualifications: v)),
          ),
          Row(
            children: [
              Expanded(
                child: _number(
                  'Experience years',
                  p.experienceYears,
                  readOnly,
                  (v) => set(p.copyWith(experienceYears: v)),
                  maxLength: 2,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _numberDouble(
                  'Consultation fee',
                  p.consultationFee,
                  readOnly,
                  (v) => set(p.copyWith(consultationFee: v)),
                ),
              ),
            ],
          ),
          _text(
            'Registration number',
            p.registrationNumber,
            readOnly,
            (v) => set(p.copyWith(registrationNumber: v)),
          ),
        ] else ...[
          _text(
            'Clinic name *',
            p.clinicName,
            readOnly,
            (v) => set(p.copyWith(clinicName: v)),
          ),
          _text(
            'Clinic phone',
            p.phone,
            readOnly,
            (v) => set(p.copyWith(phone: v)),
          ),
          _text(
            'Clinic email',
            p.clinicEmail,
            readOnly,
            (v) => set(p.copyWith(clinicEmail: v)),
          ),
          _text(
            'Address',
            p.address,
            readOnly,
            (v) => set(p.copyWith(address: v)),
            lines: 2,
          ),
          Row(
            children: [
              Expanded(
                child: _text(
                  'City',
                  p.city,
                  readOnly,
                  (v) => set(p.copyWith(city: v)),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _text(
                  'State',
                  p.state,
                  readOnly,
                  (v) => set(p.copyWith(state: v)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ServicesEditor extends ConsumerWidget {
  const _ServicesEditor({required this.snapshot, required this.readOnly});
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot.settings;
    void set(List<WebsiteService> rows) =>
        ref.read(websiteProvider.notifier).updateServices(rows);
    return Column(
      children: [
        _switch(
          'Show services',
          s.showServices,
          readOnly
              ? null
              : (v) => ref
                    .read(websiteProvider.notifier)
                    .updateSettings(s.copyWith(showServices: v)),
        ),
        for (final row in snapshot.services)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.03),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Switch(
                value: row.active,
                activeThumbColor: AppColors.primary,
                onChanged: readOnly
                    ? null
                    : (v) => set([
                        for (final item in snapshot.services)
                          if (item.id == row.id)
                            item.copyWith(active: v)
                          else
                            item,
                      ]),
              ),
              title: Text(
                row.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${row.type} · ${row.durationMinutes} min · ₹${row.price.toStringAsFixed(0)}',
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    onPressed: readOnly
                        ? null
                        : () async {
                            final changed = await _serviceForm(context, row);
                            if (changed != null) {
                              set([
                                for (final item in snapshot.services)
                                  if (item.id == row.id) changed else item,
                              ]);
                            }
                          },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: readOnly
                        ? null
                        : () => set(
                            snapshot.services
                                .where((item) => item.id != row.id)
                                .toList(),
                          ),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.destructive,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
            onPressed: readOnly
                ? null
                : () async {
                    final row = await _serviceForm(
                      context,
                      WebsiteService(
                        id: 'new-${DateTime.now().microsecondsSinceEpoch}',
                        name: '',
                        description: '',
                        price: 500,
                        type: 'clinic',
                        durationMinutes: 30,
                        active: true,
                        sortOrder: snapshot.services.length,
                      ),
                    );
                    if (row != null) set([...snapshot.services, row]);
                  },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add service'),
          ),
        ),
      ],
    );
  }
}

// Kept for decoding older website snapshots; packages are intentionally no
// longer exposed in the mobile Microsite editor.
// ignore: unused_element
class _PackagesEditor extends ConsumerWidget {
  const _PackagesEditor({required this.snapshot, required this.readOnly});
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot.settings;
    void set(List<WebsitePackage> rows) =>
        ref.read(websiteProvider.notifier).updatePackages(rows);
    return Column(
      children: [
        _switch(
          'Show packages',
          s.showPackages,
          readOnly
              ? null
              : (v) => ref
                    .read(websiteProvider.notifier)
                    .updateSettings(s.copyWith(showPackages: v)),
        ),
        for (final row in snapshot.packages)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.03),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Switch(
                value: row.active,
                activeThumbColor: AppColors.primary,
                onChanged: readOnly
                    ? null
                    : (v) => set([
                        for (final item in snapshot.packages)
                          if (item.id == row.id)
                            item.copyWith(active: v)
                          else
                            item,
                      ]),
              ),
              title: Text(
                row.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${row.duration} · ₹${row.price.toStringAsFixed(0)}${row.isPopular ? ' · Popular' : ''}',
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    onPressed: readOnly
                        ? null
                        : () async {
                            final changed = await _packageForm(context, row);
                            if (changed != null) {
                              set([
                                for (final item in snapshot.packages)
                                  if (item.id == row.id) changed else item,
                              ]);
                            }
                          },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: readOnly
                        ? null
                        : () => set(
                            snapshot.packages
                                .where((item) => item.id != row.id)
                                .toList(),
                          ),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.destructive,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
            onPressed: readOnly
                ? null
                : () async {
                    final row = await _packageForm(
                      context,
                      WebsitePackage(
                        id: 'new-${DateTime.now().microsecondsSinceEpoch}',
                        name: '',
                        price: 0,
                        features: const [],
                        active: true,
                        isPopular: false,
                        sortOrder: snapshot.packages.length,
                      ),
                    );
                    if (row != null) set([...snapshot.packages, row]);
                  },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add package'),
          ),
        ),
      ],
    );
  }
}

class _GalleryEditor extends ConsumerWidget {
  const _GalleryEditor({
    required this.snapshot,
    required this.readOnly,
    required this.upload,
    required this.message,
  });
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  final VoidCallback upload;
  final ValueChanged<String> message;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot.settings;
    return Column(
      children: [
        _switch(
          'Show gallery',
          s.showGallery,
          readOnly
              ? null
              : (v) => ref
                    .read(websiteProvider.notifier)
                    .updateSettings(s.copyWith(showGallery: v)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: snapshot.gallery.length,
          itemBuilder: (context, index) {
            final photo = snapshot.gallery[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.network(
                    photo.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.lightMuted,
                      child: Icon(Icons.broken_image_rounded),
                    ),
                  ),
                ),
                if (!readOnly)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () async {
                        final error = await ref
                            .read(websiteProvider.notifier)
                            .deleteGallery(photo.id);
                        message(error ?? 'Photo deleted.');
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.destructive,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 2,
                  bottom: 2,
                  right: 2,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: readOnly
                          ? null
                          : () async {
                              final value = await _captionDialog(
                                context,
                                photo.caption ?? '',
                              );
                              if (value != null) {
                                final error = await ref
                                    .read(websiteProvider.notifier)
                                    .updateCaption(photo.id, value);
                                message(error ?? 'Caption saved.');
                              }
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Text(
                          photo.caption?.isNotEmpty == true
                              ? photo.caption!
                              : 'Add caption',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: _WebsiteType.label,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
            onPressed: readOnly || snapshot.gallery.length >= 6 ? null : upload,
            icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
            label: Text(
              snapshot.gallery.length >= 6
                  ? 'Gallery limit reached'
                  : 'Upload photo',
            ),
          ),
        ),
      ],
    );
  }
}

class _HoursEditor extends ConsumerWidget {
  const _HoursEditor({required this.snapshot, required this.readOnly});
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  static const days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void set(WorkingHour changed) =>
        ref.read(websiteProvider.notifier).updateHours([
          for (final row in snapshot.workingHours)
            if (row.dayOfWeek == changed.dayOfWeek) changed else row,
        ]);
    return Column(
      children: [
        for (final row in snapshot.workingHours)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              color: row.isOpen
                  ? AppColors.primary.withOpacity(0.03)
                  : AppColors.onSurface(context).withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primary,
                  title: Text(
                    days[row.dayOfWeek],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    row.isOpen
                        ? '${row.startTime ?? '09:00'} - ${row.endTime ?? '17:00'}${row.startTime2 == null ? '' : ' / ${row.startTime2} - ${row.endTime2}'}'
                        : 'Closed',
                  ),
                  value: row.isOpen,
                  onChanged: readOnly
                      ? null
                      : (v) => set(
                          row.copyWith(
                            isOpen: v,
                            startTime: v
                                ? row.startTime ?? '09:00'
                                : row.startTime,
                            endTime: v ? row.endTime ?? '17:00' : row.endTime,
                          ),
                        ),
                ),
                if (row.isOpen)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: readOnly
                              ? null
                              : () async {
                                  final v = await _time(
                                    context,
                                    row.startTime ?? '09:00',
                                  );
                                  if (v != null) {
                                    set(row.copyWith(startTime: v));
                                  }
                                },
                          child: Text('Start ${row.startTime ?? '09:00'}'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: readOnly
                              ? null
                              : () async {
                                  final v = await _time(
                                    context,
                                    row.endTime ?? '17:00',
                                  );
                                  if (v != null) set(row.copyWith(endTime: v));
                                },
                          child: Text('End ${row.endTime ?? '17:00'}'),
                        ),
                      ),
                      IconButton(
                        onPressed: readOnly
                            ? null
                            : () => set(
                                row.startTime2 == null
                                    ? row.copyWith(
                                        startTime2: '18:00',
                                        endTime2: '20:00',
                                      )
                                    : row.copyWith(clearSecond: true),
                              ),
                        tooltip: row.startTime2 == null
                            ? 'Add second shift'
                            : 'Remove second shift',
                        icon: Icon(
                          row.startTime2 == null
                              ? Icons.add_alarm_rounded
                              : Icons.alarm_off_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                if (row.isOpen && row.startTime2 != null)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: readOnly
                              ? null
                              : () async {
                                  final v = await _time(
                                    context,
                                    row.startTime2!,
                                  );
                                  if (v != null) {
                                    set(row.copyWith(startTime2: v));
                                  }
                                },
                          child: Text('Shift 2 start ${row.startTime2}'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: readOnly
                              ? null
                              : () async {
                                  final v = await _time(
                                    context,
                                    row.endTime2 ?? '20:00',
                                  );
                                  if (v != null) {
                                    set(row.copyWith(endTime2: v));
                                  }
                                },
                          child: Text('Shift 2 end ${row.endTime2 ?? '20:00'}'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BookingEditor extends ConsumerWidget {
  const _BookingEditor({required this.snapshot, required this.readOnly});
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot.settings;
    void set(WebsiteSettings v) =>
        ref.read(websiteProvider.notifier).updateSettings(v);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _number(
                'Advance days (1-365)',
                s.bookingAdvanceDays,
                readOnly,
                (v) => set(s.copyWith(bookingAdvanceDays: v)),
                maxLength: 3,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _number(
                'Patients / slot (1-50)',
                s.maxPerSlot,
                readOnly,
                (v) => set(s.copyWith(maxPerSlot: v)),
                maxLength: 2,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _number(
                'Cancel cutoff hours',
                s.cancellationCutoffHours,
                readOnly,
                (v) => set(s.copyWith(cancellationCutoffHours: v)),
                maxLength: 3,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: [0, 5, 10, 15].contains(s.bufferMinutes)
                    ? s.bufferMinutes
                    : 0,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: _WebsiteType.body,
                  fontWeight: FontWeight.w500,
                ),
                decoration: _fieldDecoration('Buffer minutes'),
                items: const [0, 5, 10, 15]
                    .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                    .toList(),
                onChanged: readOnly
                    ? null
                    : (v) => set(s.copyWith(bufferMinutes: v)),
              ),
            ),
          ],
        ),
        _switch(
          'Auto-confirm bookings',
          s.autoConfirm,
          readOnly ? null : (v) => set(s.copyWith(autoConfirm: v)),
        ),
        _switch(
          'Require online payment',
          s.requirePayment,
          readOnly ? null : (v) => set(s.copyWith(requirePayment: v)),
        ),
      ],
    );
  }
}

class _OnlineEditor extends ConsumerWidget {
  const _OnlineEditor({required this.snapshot, required this.readOnly});
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot.settings;
    void set(WebsiteSettings v) =>
        ref.read(websiteProvider.notifier).updateSettings(v);
    return Column(
      children: [
        _switch(
          'Enable online consultation',
          s.showOnlineConsultation,
          readOnly ? null : (v) => set(s.copyWith(showOnlineConsultation: v)),
        ),
        Row(
          children: [
            Expanded(
              child: _numberDouble(
                'Online fee ₹',
                s.onlineFee,
                readOnly,
                (v) => set(s.copyWith(onlineFee: v)),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: [15, 30, 45, 60].contains(s.onlineDuration)
                    ? s.onlineDuration
                    : 30,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: _WebsiteType.body,
                  fontWeight: FontWeight.w500,
                ),
                decoration: _fieldDecoration('Duration'),
                items: const [15, 30, 45, 60]
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text('$v min')),
                    )
                    .toList(),
                onChanged: readOnly
                    ? null
                    : (v) => set(s.copyWith(onlineDuration: v)),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.06),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.videocam_rounded, color: AppColors.success),
            title: Text('Video provider'),
            subtitle: Text('Zoom · Connected'),
          ),
        ),
      ],
    );
  }
}

class _LockedOnline extends StatelessWidget {
  const _LockedOnline();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.04),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.primary.withOpacity(0.12)),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.12),
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Online Consultation',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'Available on Premium. Upgrade to enable video consultations.',
                style: TextStyle(fontSize: _WebsiteType.body),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReviewsEditor extends ConsumerWidget {
  const _ReviewsEditor({
    required this.snapshot,
    required this.readOnly,
    required this.message,
  });
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  final ValueChanged<String> message;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot.settings;
    return Column(
      children: [
        _switch(
          'Show reviews section',
          s.showReviews,
          readOnly
              ? null
              : (v) => ref
                    .read(websiteProvider.notifier)
                    .updateSettings(s.copyWith(showReviews: v)),
        ),
        if (snapshot.reviews.isEmpty)
          Text(
            'No reviews yet.',
            style: TextStyle(
              color: AppColors.onSurface(context).withValues(alpha: 0.6),
            ),
          )
        else
          for (final review in snapshot.reviews)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              decoration: BoxDecoration(
                color: review.isVisible
                    ? AppColors.primary.withOpacity(0.03)
                    : AppColors.destructive.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  review.patientName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${'★' * review.rating}${review.reviewText == null ? '' : '\n${review.reviewText}'}',
                ),
                isThreeLine: review.reviewText != null,
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: review.isPinned ? 'Unpin' : 'Pin',
                      onPressed: readOnly
                          ? null
                          : () async {
                              final error = await ref
                                  .read(websiteProvider.notifier)
                                  .updateReview(
                                    review.id,
                                    isPinned: !review.isPinned,
                                  );
                              message(
                                error ??
                                    (review.isPinned
                                        ? 'Review unpinned.'
                                        : 'Review pinned.'),
                              );
                            },
                      icon: Icon(
                        review.isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        color: review.isPinned ? AppColors.primary : null,
                      ),
                    ),
                    IconButton(
                      tooltip: review.isVisible ? 'Hide' : 'Show',
                      onPressed: readOnly
                          ? null
                          : () async {
                              final error = await ref
                                  .read(websiteProvider.notifier)
                                  .updateReview(
                                    review.id,
                                    isVisible: !review.isVisible,
                                  );
                              message(
                                error ??
                                    (review.isVisible
                                        ? 'Review hidden.'
                                        : 'Review shown.'),
                              );
                            },
                      icon: Icon(
                        review.isVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _BlogEditor extends ConsumerWidget {
  const _BlogEditor({required this.snapshot, required this.readOnly});
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot.settings;
    return _switch(
      'Show health articles on public site',
      s.showBlog,
      readOnly
          ? null
          : (v) => ref
                .read(websiteProvider.notifier)
                .updateSettings(s.copyWith(showBlog: v)),
    );
  }
}

class _ContactEditor extends ConsumerWidget {
  const _ContactEditor({required this.snapshot, required this.readOnly});
  final WebsiteSnapshot snapshot;
  final bool readOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot.settings;
    void set(WebsiteSettings v) =>
        ref.read(websiteProvider.notifier).updateSettings(v);
    return Column(
      children: [
        _text(
          'SEO title',
          s.seoTitle,
          readOnly,
          (v) => set(s.copyWith(seoTitle: v)),
        ),
        _text(
          'SEO description',
          s.seoDescription,
          readOnly,
          (v) => set(s.copyWith(seoDescription: v)),
          lines: 2,
        ),
        _text(
          'WhatsApp number',
          s.whatsappNumber,
          readOnly,
          (v) => set(s.copyWith(whatsappNumber: v)),
        ),
        _text(
          'WhatsApp pre-fill message',
          s.whatsappMessage,
          readOnly,
          (v) => set(s.copyWith(whatsappMessage: v)),
        ),
        _text(
          'Facebook URL',
          s.socialFacebook,
          readOnly,
          (v) => set(s.copyWith(socialFacebook: v)),
        ),
        _text(
          'Instagram URL',
          s.socialInstagram,
          readOnly,
          (v) => set(s.copyWith(socialInstagram: v)),
        ),
        _text(
          'YouTube URL',
          s.socialYoutube,
          readOnly,
          (v) => set(s.copyWith(socialYoutube: v)),
        ),
        _text(
          'LinkedIn URL',
          s.socialLinkedin,
          readOnly,
          (v) => set(s.copyWith(socialLinkedin: v)),
        ),
        _text(
          'Google Analytics ID',
          s.googleAnalyticsId,
          readOnly,
          (v) => set(s.copyWith(googleAnalyticsId: v)),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(
    fontSize: _WebsiteType.label,
    fontWeight: FontWeight.w600,
  ),
  filled: true,
  fillColor: _kFieldFill,
  contentPadding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: 12,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: BorderSide(color: _kHairline),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: BorderSide(color: _kHairline),
  ),
);

Widget _text(
  String label,
  String value,
  bool disabled,
  ValueChanged<String> changed, {
  int lines = 1,
}) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
  child: TextFormField(
    initialValue: value,
    enabled: !disabled,
    maxLines: lines,
    style: const TextStyle(
      fontSize: _WebsiteType.body,
      fontWeight: FontWeight.w500,
    ),
    decoration: _fieldDecoration(label),
    onChanged: changed,
  ),
);
Widget _number(
  String label,
  int value,
  bool disabled,
  ValueChanged<int> changed, {
  int? maxLength,
}) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
  child: TextFormField(
    initialValue: '$value',
    enabled: !disabled,
    style: const TextStyle(
      fontSize: _WebsiteType.body,
      fontWeight: FontWeight.w500,
    ),
    keyboardType: TextInputType.number,
    maxLength: maxLength,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: _fieldDecoration(label),
    onChanged: (v) => changed(int.tryParse(v) ?? 0),
  ),
);
Widget _numberDouble(
  String label,
  double value,
  bool disabled,
  ValueChanged<double> changed,
) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
  child: TextFormField(
    initialValue: value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2),
    enabled: !disabled,
    style: const TextStyle(
      fontSize: _WebsiteType.body,
      fontWeight: FontWeight.w500,
    ),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: _fieldDecoration(label),
    onChanged: (v) => changed(double.tryParse(v) ?? 0),
  ),
);
Widget _switch(String label, bool value, ValueChanged<bool>? changed) =>
    Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: _kHairline),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AppColors.primary,
        title: Text(
          label,
          style: const TextStyle(
            fontSize: _WebsiteType.body,
            fontWeight: FontWeight.w600,
          ),
        ),
        value: value,
        onChanged: changed,
      ),
    );

Future<String?> _time(BuildContext context, String current) async {
  final parts = current.split(':');
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    ),
  );
  return picked == null
      ? null
      : '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
}

Future<String?> _captionDialog(BuildContext context, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      title: const Text('Photo caption'),
      content: TextField(
        controller: c,
        decoration: _fieldDecoration('Caption'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => Navigator.pop(context, c.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<WebsiteService?> _serviceForm(
  BuildContext context,
  WebsiteService row,
) => showModalBottomSheet<WebsiteService>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _ServiceSheet(row: row),
);

class _ServiceSheet extends StatefulWidget {
  const _ServiceSheet({required this.row});
  final WebsiteService row;
  @override
  State<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<_ServiceSheet> {
  late final name = TextEditingController(text: widget.row.name),
      description = TextEditingController(text: widget.row.description),
      price = TextEditingController(text: widget.row.price.toStringAsFixed(0)),
      duration = TextEditingController(text: '${widget.row.durationMinutes}');
  late String type = widget.row.type;
  @override
  void dispose() {
    for (final c in [name, description, price, duration]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
    ),
    child: ListView(
      children: [
        Text(
          'Service',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        _field(name, 'Name *', onChanged: (_) => setState(() {})),
        _field(description, 'Description'),
        _field(price, 'Price ₹', number: true),
        _field(duration, 'Duration minutes', number: true),
        DropdownButtonFormField<String>(
          initialValue: type,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: _WebsiteType.body,
            fontWeight: FontWeight.w500,
          ),
          decoration: _fieldDecoration('Type'),
          items: const [
            'clinic',
            'online',
            'both',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => type = v!,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    widget.row.copyWith(
                      name: name.text.trim(),
                      description: description.text.trim(),
                      price: double.tryParse(price.text) ?? 0,
                      durationMinutes: int.tryParse(duration.text) ?? 0,
                      type: type,
                    ),
                  ),
            child: const Text('Done'),
          ),
        ),
      ],
    ),
  );
}

Future<WebsitePackage?> _packageForm(
  BuildContext context,
  WebsitePackage row,
) => showModalBottomSheet<WebsitePackage>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _PackageSheet(row: row),
);

class _PackageSheet extends StatefulWidget {
  const _PackageSheet({required this.row});
  final WebsitePackage row;
  @override
  State<_PackageSheet> createState() => _PackageSheetState();
}

class _PackageSheetState extends State<_PackageSheet> {
  late final name = TextEditingController(text: widget.row.name),
      tagline = TextEditingController(text: widget.row.tagline),
      price = TextEditingController(text: widget.row.price.toStringAsFixed(0)),
      original = TextEditingController(
        text: widget.row.originalPrice?.toStringAsFixed(0) ?? '',
      ),
      duration = TextEditingController(text: widget.row.duration),
      features = TextEditingController(text: widget.row.features.join('\n')),
      slots = TextEditingController(
        text: widget.row.slotsAvailable?.toString() ?? '',
      );
  late bool popular = widget.row.isPopular;
  @override
  void dispose() {
    for (final c in [
      name,
      tagline,
      price,
      original,
      duration,
      features,
      slots,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
    ),
    child: ListView(
      children: [
        Text(
          'Package',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        _field(name, 'Name *', onChanged: (_) => setState(() {})),
        _field(tagline, 'Tagline'),
        Row(
          children: [
            Expanded(child: _field(price, 'Price ₹', number: true)),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: _field(original, 'Original price', number: true)),
          ],
        ),
        _field(duration, 'Duration'),
        _field(slots, 'Slots available', number: true),
        _field(features, 'Features (one per line)', lines: 4),
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.035),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
            title: const Text('Mark as popular'),
            value: popular,
            onChanged: (v) => setState(() => popular = v),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    widget.row.copyWith(
                      name: name.text.trim(),
                      tagline: tagline.text.trim(),
                      price: double.tryParse(price.text) ?? 0,
                      originalPrice: double.tryParse(original.text),
                      clearOriginalPrice: original.text.trim().isEmpty,
                      duration: duration.text.trim(),
                      slotsAvailable: int.tryParse(slots.text),
                      clearSlotsAvailable: slots.text.trim().isEmpty,
                      features: features.text
                          .split('\n')
                          .map((v) => v.trim())
                          .where((v) => v.isNotEmpty)
                          .toList(),
                      isPopular: popular,
                    ),
                  ),
            child: const Text('Done'),
          ),
        ),
      ],
    ),
  );
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool number = false,
  int lines = 1,
  ValueChanged<String>? onChanged,
}) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
  child: TextField(
    controller: controller,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : null,
    maxLines: lines,
    onChanged: onChanged,
    decoration: _fieldDecoration(label),
  ),
);
