import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/platform/app_version.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_motion.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_form_sheet.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/blog/presentation/providers/blog_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/inquiries/presentation/providers/inquiry_providers.dart';
import 'package:doctylia_app/features/patients/presentation/widgets/patient_form_sheet.dart';
import 'package:doctylia_app/features/prescriptions/presentation/providers/prescription_providers.dart';
import 'package:doctylia_app/features/prescriptions/presentation/widgets/prescription_form_sheet.dart';
import 'package:doctylia_app/features/reviews/presentation/providers/review_providers.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  /// Every module, grouped by area. Titles are unchanged (people and tests
  /// find modules by name); each opens its route with `context.push`.
  static const groups = [
    _Group(
      title: 'Clinical Practice',
      icon: Icons.medical_services_outlined,
      modules: [
        _Module(
          title: 'Prescriptions',
          subtitle: 'Digital Rx, renewals & follow-ups',
          path: RoutePaths.prescriptions,
          icon: Icons.science_outlined,
          color: DashboardTokens.tealDeep,
        ),
        _Module(
          title: 'Inquiries',
          subtitle: 'Website patient questions',
          path: RoutePaths.inquiries,
          icon: Icons.mail_outline_rounded,
          color: AppColors.primary600,
        ),
      ],
    ),
    _Group(
      title: 'Financials & Growth',
      icon: Icons.trending_up_rounded,
      modules: [
        _Module(
          title: 'Billing',
          subtitle: 'Invoices, patient dues & earnings',
          path: RoutePaths.billing,
          icon: Icons.receipt_long_outlined,
          color: AppColors.orange,
        ),
        _Module(
          title: 'Reviews',
          subtitle: 'Ratings & testimonials',
          path: RoutePaths.reviews,
          icon: Icons.star_rounded,
          color: AppColors.warning,
        ),
        _Module(
          title: 'My Website',
          subtitle: 'Public booking page & practice portal',
          path: RoutePaths.myWebsite,
          icon: Icons.language_rounded,
          color: AppColors.success,
        ),
      ],
    ),
    _Group(
      title: 'Content & Communication',
      icon: Icons.campaign_outlined,
      modules: [
        _Module(
          title: 'Blog',
          subtitle: 'Articles for your patients',
          path: RoutePaths.blog,
          icon: Icons.newspaper_outlined,
          color: AppColors.pink,
        ),
      ],
    ),
    _Group(
      title: 'Practice & Support',
      icon: Icons.tune_rounded,
      modules: [
        _Module(
          title: 'Staff Management',
          subtitle: 'Team access, roles & permissions',
          path: RoutePaths.staff,
          icon: Icons.groups_outlined,
          color: DashboardTokens.teal,
        ),
        _Module(
          title: 'Settings',
          subtitle: 'Profile, clinic, payouts & plan',
          path: RoutePaths.settings,
          icon: Icons.settings_outlined,
          color: AppColors.primary,
        ),
        _Module(
          title: 'Contact Support',
          subtitle: 'Help articles, tickets & live support',
          path: RoutePaths.support,
          icon: Icons.support_agent_rounded,
          color: AppColors.success,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(doctorProfileProvider);
    // Trial grace access is read-only, as on the module screens.
    final readOnly =
        ref.watch(trialStatusProvider).accessLevel == TrialAccessLevel.grace;
    final badges = _badges(ref);
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RoutePaths.dashboard);
      },
      child: DashboardShadcnScope(
        child: AppMotion(
          enabled: true,
          child: _CascadeWindow(
            builder: (entrance) => ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                110,
              ),
              children: [
                entrance(0, _HubHeader(profile: profile)),
                const SizedBox(height: 14),
                entrance(1, _QuickActions(readOnly: readOnly)),
                for (final (i, group) in groups.indexed) ...[
                  const SizedBox(height: 18),
                  entrance(2 + i, _ModuleGroup(group: group, badges: badges)),
                ],
                const SizedBox(height: 18),
                entrance(
                  2 + groups.length,
                  _SessionCard(
                    onLogout: () => DashboardShell.confirmLogout(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Live indicators from the stats the module screens already use (cached
  /// app-wide and refreshed when their data changes). Null = no badge;
  /// [_TileBadge.loading] = placeholder while the count loads.
  static Map<String, _TileBadge?> _badges(WidgetRef ref) {
    _TileBadge? from<T>(
      AsyncValue<T> value,
      _TileBadge? Function(T data) build,
    ) => value.when(
      data: build,
      loading: () => _TileBadge.loading,
      error: (_, _) => null,
    );

    return {
      RoutePaths.inquiries: from(
        ref.watch(inquiryStatsProvider),
        (s) => s.newCount > 0
            ? _TileBadge('${s.newCount} New', DashboardTokens.tealDeep)
            : null,
      ),
      RoutePaths.reviews: from(
        ref.watch(reviewStatsProvider),
        (s) => s.total > 0
            ? _TileBadge(
                s.averageRating.toStringAsFixed(1),
                AppColors.warning,
                icon: Icons.star_rounded,
              )
            : null,
      ),
      RoutePaths.blog: from(
        ref.watch(blogStatsProvider),
        (s) => s.drafts > 0
            ? _TileBadge(
                '${s.drafts} ${s.drafts == 1 ? 'draft' : 'drafts'}',
                AppColors.orange,
              )
            : null,
      ),
      RoutePaths.myWebsite: from(
        ref.watch(dashboardProvider),
        (s) => s.websiteIsLive
            ? const _TileBadge('Live', AppColors.success, dot: true)
            : null,
      ),
    };
  }
}

/// Items built in the screen's first half-second cascade in; items the
/// list builds later (scrolled into view) just appear, instead of waiting
/// out a long stagger delay.
class _CascadeWindow extends StatefulWidget {
  const _CascadeWindow({required this.builder});

  final Widget Function(Widget Function(int index, Widget child) entrance)
  builder;

  @override
  State<_CascadeWindow> createState() => _CascadeWindowState();
}

class _CascadeWindowState extends State<_CascadeWindow> {
  final _age = Stopwatch()..start();

  Widget _entrance(int index, Widget child) => AppEntrance(
    index: index,
    step: const Duration(milliseconds: 35),
    // ~12px of slide on a typical section.
    offset: const Offset(0, 0.06),
    enabled: _age.elapsedMilliseconds < 500,
    child: child,
  );

  @override
  Widget build(BuildContext context) => widget.builder(_entrance);
}

// ── Header & identity strip ──────────────────────────────────────────────

class _HubHeader extends ConsumerWidget {
  const _HubHeader({required this.profile});

  final DoctorProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = _doctorName(profile?.fullName);
    final clinic = profile?.clinicName?.trim();
    final specialty = profile?.specialization?.trim();
    final photo = profile?.profilePhotoUrl?.trim();
    final version = ref.watch(appVersionProvider);
    final initials = Text(
      _initials(name),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
    final versionStyle = TextStyle(
      color: AppColors.subtleText(context),
      fontSize: 11,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Practice Hub',
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Every tool for your practice, in one place',
          style: TextStyle(color: AppColors.mutedText(context), fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        DashboardSurface(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primary600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: photo == null || photo.isEmpty
                    ? initials
                    : Image.network(
                        photo,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => initials,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.onSurface(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      clinic == null || clinic.isEmpty
                          ? 'Doctylia practice'
                          : clinic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.mutedText(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (specialty != null && specialty.isNotEmpty)
                          DashboardToneBadge(
                            label: specialty,
                            color: DashboardTokens.tealDeep,
                            icon: Icons.medical_services_outlined,
                          ),
                        // Read from the platform; fades in once known.
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: version.value == null
                              ? const SizedBox.shrink()
                              : Text(version.value!, style: versionStyle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _doctorName(String? value) {
    final name = value?.trim();
    if (name == null || name.isEmpty) return 'Doctor';
    return name.startsWith('Dr.') ? name : 'Dr. $name';
  }

  static String _initials(String value) {
    final clean = value.replaceFirst(RegExp(r'^Dr\.?\s*'), '').trim();
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'DR';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

// ── Quick actions ────────────────────────────────────────────────────────

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.readOnly});

  /// Create actions are disabled during read-only trial grace access.
  final bool readOnly;

  Future<void> _newPrescription(BuildContext context, WidgetRef ref) async {
    // Same flow as the Prescriptions screen's "New" button.
    ref.invalidate(prescriptionPatientsProvider);
    final value = await showPrescriptionForm(context, ref);
    if (value != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prescription saved')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget row(Widget a, Widget b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GroupLabel(icon: Icons.bolt_rounded, title: 'Quick actions'),
        row(
          _QuickAction(
            icon: Icons.medication_outlined,
            label: 'New Prescription',
            caption: 'Write a digital Rx',
            color: DashboardTokens.tealDeep,
            locked: readOnly,
            onTap: () => _newPrescription(context, ref),
          ),
          _QuickAction(
            icon: Icons.edit_calendar_outlined,
            label: 'Book Appointment',
            caption: 'Schedule a visit',
            color: AppColors.primary600,
            locked: readOnly,
            onTap: () => showAppointmentForm(context, ref),
          ),
        ),
        const SizedBox(height: 10),
        row(
          _QuickAction(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Add Patient',
            caption: 'Create a patient record',
            color: AppColors.success,
            locked: readOnly,
            onTap: () => showPatientForm(context, ref),
          ),
          _QuickAction(
            icon: Icons.receipt_long_outlined,
            label: 'Billing & Dues',
            caption: 'Invoices & payments',
            color: AppColors.warning,
            onTap: () => context.push(RoutePaths.billing),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final String caption;
  final Color color;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final card = AppColors.isDark(context)
        ? AppColors.darkCard
        : AppColors.card;
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DashboardIconTile(icon: icon, color: color, size: 36),
              const Spacer(),
              if (locked)
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: AppColors.subtleText(context),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            locked ? 'Read-only access' : caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.mutedText(context), fontSize: 11),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: !locked,
      child: DashboardSurface(
        padding: EdgeInsets.zero,
        fillColor: Color.alphaBlend(
          color.withValues(alpha: locked ? 0.02 : 0.06),
          card,
        ),
        borderColor: color.withValues(alpha: locked ? 0.12 : 0.22),
        onTap: locked ? null : onTap,
        child: Opacity(opacity: locked ? 0.6 : 1, child: content),
      ),
    );
  }
}

// ── Grouped module cards ─────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.subtleText(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardTokens.eyebrow(context),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              color: AppColors.subtleText(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
  );
}

class _ModuleGroup extends StatelessWidget {
  const _ModuleGroup({required this.group, required this.badges});

  final _Group group;
  final Map<String, _TileBadge?> badges;

  @override
  Widget build(BuildContext context) {
    final count = group.modules.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupLabel(
          icon: group.icon,
          title: group.title,
          trailing: '$count ${count == 1 ? 'tool' : 'tools'}',
        ),
        shadcn.Card(
          padding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(DashboardTokens.radius),
          borderColor: DashboardTokens.border(context),
          boxShadow: DashboardTokens.shadow(context),
          child: Column(
            children: [
              for (final (i, module) in group.modules.indexed) ...[
                if (i > 0)
                  shadcn.Divider(
                    color: DashboardTokens.border(context),
                    indent: 66,
                    endIndent: 14,
                  ),
                _ModuleTile(module: module, badge: badges[module.path]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module, this.badge});

  final _Module module;
  final _TileBadge? badge;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: () => context.push(module.path),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: module.color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: module.color.withValues(alpha: 0.18)),
              ),
              child: Icon(module.icon, size: 19, color: module.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.onSurface(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    module.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.mutedText(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              // Fades in when a count arrives or changes.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(badge!.label),
                  child: identical(badge, _TileBadge.loading)
                      ? _skeleton(
                          context,
                          const DashboardToneBadge(
                            label: '00 New',
                            color: AppColors.textLight,
                          ),
                        )
                      : DashboardToneBadge(
                          label: badge!.label,
                          color: badge!.color,
                          icon: badge!.icon,
                          showDot: badge!.dot,
                        ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.subtleText(context),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Session ──────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final card = AppColors.isDark(context)
        ? AppColors.darkCard
        : AppColors.card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GroupLabel(icon: Icons.shield_outlined, title: 'Session'),
        DashboardSurface(
          padding: const EdgeInsets.all(14),
          fillColor: Color.alphaBlend(
            AppColors.destructive.withValues(alpha: 0.04),
            card,
          ),
          borderColor: AppColors.destructive.withValues(alpha: 0.22),
          child: Row(
            children: [
              const DashboardIconTile(
                icon: Icons.logout_rounded,
                color: AppColors.destructive,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Signed in on this device',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.mutedText(context),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  backgroundColor: AppColors.destructive.withValues(
                    alpha: 0.06,
                  ),
                  side: BorderSide(
                    color: AppColors.destructive.withValues(alpha: 0.35),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  // From the theme so the app font (Inter) is kept.
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Log out'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────

/// Renders [child]'s real layout as a soft pulsing placeholder.
Widget _skeleton(BuildContext context, Widget child) {
  final isDark = AppColors.isDark(context);
  return Skeleton(
    semanticsLabel: 'Loading',
    palette: SkeletonPalette(
      surface: isDark ? AppColors.darkCard : AppColors.card,
      surfaceBorder: DashboardTokens.border(context),
      bone: isDark ? AppColors.darkBorder : AppColors.secondarySurface(context),
      innerSurface: isDark
          ? AppColors.darkSecondary
          : AppColors.secondarySurface(context).withValues(alpha: 0.55),
    ),
    child: child,
  );
}

class _TileBadge {
  const _TileBadge(this.label, this.color, {this.icon, this.dot = false});

  /// Placeholder while a count loads.
  static const loading = _TileBadge('…', AppColors.textLight);

  final String label;
  final Color color;
  final IconData? icon;
  final bool dot;
}

class _Group {
  const _Group({
    required this.title,
    required this.icon,
    required this.modules,
  });

  final String title;
  final IconData icon;
  final List<_Module> modules;
}

class _Module {
  const _Module({
    required this.title,
    required this.subtitle,
    required this.path,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String path;
  final IconData icon;
  final Color color;
}
