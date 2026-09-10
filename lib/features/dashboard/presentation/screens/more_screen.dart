import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const modules = [
    _Module(
      title: 'Prescriptions',
      subtitle: 'Manage digital Rx templates & history',
      path: RoutePaths.prescriptions,
      icon: Icons.science_outlined,
      color: AppColors.teal,
    ),
    _Module(
      title: 'Billing',
      subtitle: 'Invoices, patient dues & clinic earnings',
      path: RoutePaths.billing,
      icon: Icons.receipt_long_outlined,
      color: AppColors.orange,
    ),
    _Module(
      title: 'Settings',
      subtitle: 'Profile, clinic slots & consultation fee',
      path: RoutePaths.settings,
      icon: Icons.settings_outlined,
      color: AppColors.primary,
    ),
    _Module(
      title: 'My Website',
      subtitle: 'Public booking page & practice portal',
      path: RoutePaths.myWebsite,
      icon: Icons.language_rounded,
      color: AppColors.success,
      badge: 'Live',
    ),
    _Module(
      title: 'Blog',
      subtitle: 'Articles & health awareness tips',
      path: RoutePaths.blog,
      icon: Icons.newspaper_outlined,
      color: AppColors.pink,
    ),
    _Module(
      title: 'Reviews',
      subtitle: 'Ratings, testimonials & feedback',
      path: RoutePaths.reviews,
      icon: Icons.star_rounded,
      color: AppColors.warning,
    ),
    _Module(
      title: 'Inquiries',
      subtitle: 'Online consultation & patient questions',
      path: RoutePaths.inquiries,
      icon: Icons.mail_outline_rounded,
      color: AppColors.primary,
    ),
    _Module(
      title: 'Staff Management',
      subtitle: 'Team access, roles & permissions',
      path: RoutePaths.staff,
      icon: Icons.groups_outlined,
      color: AppColors.teal,
    ),
    _Module(
      title: 'Contact Support',
      subtitle: 'Help, requests & Doctylia assistance',
      path: RoutePaths.support,
      icon: Icons.support_agent_rounded,
      color: AppColors.success,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(doctorProfileProvider);
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RoutePaths.dashboard);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          110,
        ),
        children: [
          _DoctorServiceHeader(profile: profile),
          const SizedBox(height: 18),
          _ServicesHeading(count: modules.length),
          const SizedBox(height: 12),
          for (final module in modules) ...[
            _ModuleCard(module: module),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
                side: BorderSide(
                  color: AppColors.destructive.withValues(alpha: 0.35),
                ),
                backgroundColor: Theme.of(context).cardColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => DashboardShell.confirmLogout(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorServiceHeader extends StatelessWidget {
  const _DoctorServiceHeader({required this.profile});

  final DoctorProfile? profile;

  @override
  Widget build(BuildContext context) {
    final name = _doctorName(profile?.fullName);
    final details = [
      profile?.specialization?.trim(),
      profile?.clinicName?.trim(),
    ].whereType<String>().where((value) => value.isNotEmpty).join(' • ');
    final photo = profile?.profilePhotoUrl?.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary600],
        ),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: photo == null || photo.isEmpty
                ? Text(
                    _initials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Image.network(
                    photo,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Text(
                      _initials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details.isEmpty ? 'Doctylia practice' : details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: const Text(
              'Online',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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

class _ServicesHeading extends StatelessWidget {
  const _ServicesHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ALL MODULES & SERVICES',
              style: TextStyle(
                color: AppColors.onSurface(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count practice tools connected & active',
              style: TextStyle(
                color: AppColors.mutedText(context),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary50,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.primary200),
        ),
        child: const Text(
          'Sync active',
          style: TextStyle(
            color: AppColors.primary600,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module});

  final _Module module;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).cardColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
    ),
    elevation: 0,
    shadowColor: Colors.black.withValues(alpha: 0.08),
    child: InkWell(
      onTap: () => context.push(module.path),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: module.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: module.color.withValues(alpha: 0.2)),
              ),
              child: Icon(module.icon, size: 20, color: module.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          module.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.onSurface(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (module.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            module.badge!,
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    module.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.mutedText(context),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

class _Module {
  const _Module({
    required this.title,
    required this.subtitle,
    required this.path,
    required this.icon,
    required this.color,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String path;
  final IconData icon;
  final Color color;
  final String? badge;
}
