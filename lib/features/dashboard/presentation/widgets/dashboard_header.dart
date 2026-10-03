import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({required this.session, super.key});

  final DoctorSession? session;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = _greetingFor(now.hour);
    final name = _doctorName(session?.displayName);

    return Container(
      constraints: const BoxConstraints(minHeight: 172),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF264CC9), Color(0xFF3471F3)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2455D6).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(right: -68, top: -86, child: _HeaderGlow(size: 190)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(greeting.icon, size: 13, color: Colors.white),
                    const SizedBox(width: 5),
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
              const SizedBox(height: 13),
              Text(
                '${greeting.label},\nDr. $name',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.14,
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
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
            ],
          ),
        ],
      ),
    );
  }

  static String _doctorName(String? displayName) {
    final clean = (displayName ?? 'Doctor')
        .replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '')
        .trim();
    return clean.isEmpty ? 'Doctor' : clean.split(RegExp(r'\s+')).first;
  }

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
  const _HeaderGlow({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.035),
      ),
    ),
  );
}
