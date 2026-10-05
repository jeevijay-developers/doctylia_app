import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({required this.session, super.key});

  final DoctorSession? session;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = _greetingFor(now.hour);
    final name = _doctorName(session?.displayName);

    return DashboardShadcnScope(
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DashboardTokens.blueDeep,
              AppColors.primary600,
              DashboardTokens.tealDeep,
            ],
            stops: [0, 0.55, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: DashboardTokens.blueDeep.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              right: -70,
              top: -90,
              child: _HeaderGlow(size: 200, alpha: 0.06),
            ),
            const Positioned(
              right: 30,
              bottom: -80,
              child: _HeaderGlow(size: 120, alpha: 0.05),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    shadcn.Avatar(
                      initials: shadcn.Avatar.getInitials(
                        _cleanName(session?.displayName),
                      ),
                      size: 48,
                      borderRadius: 14,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      theme: const shadcn.AvatarTheme(
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      badge: const shadcn.AvatarBadge(
                        size: 12,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                greeting.icon,
                                size: 13,
                                color: const Color(0xFFBFE9FF),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  greeting.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFD5E4FF),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dr. $name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 23,
                                  height: 1.15,
                                  letterSpacing: -0.5,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Here is an overview of your clinical performance and '
                  'appointments today.',
                  style: TextStyle(
                    color: Color(0xFFDCE7FF),
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      // Long dates ("Wednesday, September 30, 2026") overflowed
                      // narrow phones; shrink to fit instead.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(now),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _cleanName(String? displayName) {
    final clean = (displayName ?? 'Doctor')
        .replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '')
        .trim();
    return clean.isEmpty ? 'Doctor' : clean;
  }

  static String _doctorName(String? displayName) =>
      _cleanName(displayName).split(RegExp(r'\s+')).first;

  static _Greeting _greetingFor(int hour) {
    if (hour < 12) {
      return const _Greeting('Good morning', Icons.wb_twilight_rounded);
    }
    if (hour < 17) {
      return const _Greeting('Good afternoon', Icons.wb_sunny_rounded);
    }
    return const _Greeting('Good evening', Icons.nightlight_round);
  }
}

class _Greeting {
  const _Greeting(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _HeaderGlow extends StatelessWidget {
  const _HeaderGlow({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    ),
  );
}
