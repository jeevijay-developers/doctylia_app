import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// A dialling country offered on the phone login screen.
class AuthCountry {
  const AuthCountry({
    required this.name,
    required this.flag,
    required this.dialCode,
    required this.minDigits,
    required this.maxDigits,
  });

  final String name;
  final String flag;
  final String dialCode;
  final int minDigits;
  final int maxDigits;

  static const india = AuthCountry(
    name: 'India',
    flag: '🇮🇳',
    dialCode: '+91',
    minDigits: 10,
    maxDigits: 10,
  );

  static const all = [
    india,
    AuthCountry(
      name: 'United Arab Emirates',
      flag: '🇦🇪',
      dialCode: '+971',
      minDigits: 9,
      maxDigits: 9,
    ),
    AuthCountry(
      name: 'Saudi Arabia',
      flag: '🇸🇦',
      dialCode: '+966',
      minDigits: 9,
      maxDigits: 9,
    ),
    AuthCountry(
      name: 'United Kingdom',
      flag: '🇬🇧',
      dialCode: '+44',
      minDigits: 10,
      maxDigits: 10,
    ),
    AuthCountry(
      name: 'United States',
      flag: '🇺🇸',
      dialCode: '+1',
      minDigits: 10,
      maxDigits: 10,
    ),
  ];

  /// Validates national [digits] for this country; null when valid.
  String? validate(String digits) {
    if (digits.isEmpty) return 'Enter your mobile number';
    if (digits.length < minDigits || digits.length > maxDigits) {
      return 'Enter a valid $minDigits-digit mobile number';
    }
    if (this == india && !RegExp(r'^[6-9]').hasMatch(digits)) {
      return 'Indian mobile numbers start with 6, 7, 8 or 9';
    }
    return null;
  }

  String toE164(String digits) => '$dialCode$digits';
}

/// "← Back" on the left, the DOCTYLIA badge on the right.
class AuthTopBar extends StatelessWidget {
  const AuthTopBar({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final onSurface = AppColors.onSurface(context);
    return Row(
      children: [
        TextButton.icon(
          onPressed: onBack,
          style: TextButton.styleFrom(
            foregroundColor: onSurface,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          label: const Text('Back'),
        ),
        const Spacer(),
        const _BrandPill(),
      ],
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.primary100,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'DOCTYLIA',
            style: TextStyle(
              color: isDark ? AppColors.primary200 : AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.shield_rounded,
            size: 15,
            color: isDark ? AppColors.primary200 : AppColors.primary600,
          ),
        ],
      ),
    );
  }
}

/// White rounded illustration tile with a small pill badge overlapping its
/// bottom-right corner.
class AuthHeroCard extends StatelessWidget {
  const AuthHeroCard({
    super.key,
    required this.badgeLabel,
    required this.badgeIcon,
    this.imagePath = 'assets/images/login_screen_img.png',
  });

  final String badgeLabel;
  final IconData badgeIcon;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    const size = 164.0;
    return Center(
      child: SizedBox(
        width: size + 20,
        height: size + 14,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow(context, alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Image.asset(imagePath, fit: BoxFit.contain),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    AppColors.teal.withValues(alpha: 0.5),
                    Colors.white,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: AppColors.navy),
                    const SizedBox(width: 5),
                    Text(
                      badgeLabel,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large centred title + muted subtitle used under the hero card.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final Widget subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DefaultTextStyle.merge(
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.45,
            color: AppColors.mutedText(context),
          ),
          child: subtitle,
        ),
      ],
    );
  }
}

/// Full-width gradient call-to-action with a trailing arrow.
class AuthGradientButton extends StatelessWidget {
  const AuthGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  static const _gradientStart = Color(0xFF0B3FBF);

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null && !isLoading ? 0.6 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_gradientStart, AppColors.primary600],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary600.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(
                height: 58,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small leading icon + caption row, e.g. under the phone field.
class AuthHint extends StatelessWidget {
  const AuthHint({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.mutedText(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.success),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: color)),
        ),
      ],
    );
  }
}

/// Security pill plus "Encrypted Vault • Telehealth Certified" row.
class AuthSecurityFooter extends StatelessWidget {
  const AuthSecurityFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedText(context);
    final captionStyle = TextStyle(fontSize: 12, color: muted);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow(context, alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFF065F46),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 15,
                  color: Color(0xFF6EE7B7),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '256-bit HIPAA Compliant Medical Grade Security',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Icon(Icons.lock_outline_rounded, size: 13, color: muted),
            Text('Encrypted Vault', style: captionStyle),
            Text('•', style: captionStyle),
            Icon(Icons.medical_services_outlined, size: 13, color: muted),
            Text('Telehealth Certified', style: captionStyle),
          ],
        ),
      ],
    );
  }
}

class AuthInlineError extends StatelessWidget {
  const AuthInlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.destructive.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: AppColors.destructive.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.destructive,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.destructive),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
