import 'dart:async';

import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/security/turnstile.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/auth/presentation/state/auth_state.dart';
import 'package:doctylia_app/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Route payload for the code screen: where the code went and, for signup,
/// the name the new account is created with.
///
/// Travels as a JSON-safe map ([toExtra]/[fromExtra]): go_router round-trips
/// `extra` through its codec on refresh and drops non-JSON objects.
class OtpRequest {
  const OtpRequest({required this.phone, this.fullName});

  static OtpRequest? fromExtra(Object? extra) {
    if (extra is! Map) return null;
    final phone = extra['phone'];
    if (phone is! String) return null;
    final fullName = extra['fullName'];
    return OtpRequest(
      phone: phone,
      fullName: fullName is String ? fullName : null,
    );
  }

  Map<String, String> toExtra() => {'phone': phone, 'fullName': ?fullName};

  /// E.164 number the code was sent to.
  final String phone;

  /// Set only for signup (resends must keep `shouldCreateUser: true`).
  final String? fullName;

  bool get isSignup => fullName != null;
}

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.request});

  final OtpRequest request;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen>
    with TurnstileGate<OtpVerificationScreen> {
  static const _codeLength = 6;
  static const _resendCooldown = 30;

  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  Timer? _timer;
  int _secondsLeft = _resendCooldown;
  bool _isResending = false;
  String? _resendError;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = _resendCooldown]) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text;
    if (code.length != _codeLength) {
      _codeFocus.requestFocus();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _resendError = null);
    await ref
        .read(authControllerProvider.notifier)
        .verifyPhoneOtp(phone: widget.request.phone, token: code);
    if (!mounted) return;
    if (ref.read(authControllerProvider).value?.errorMessage != null) {
      _codeController.clear();
      _codeFocus.requestFocus();
    }
  }

  Future<void> _resend() async {
    if (captchaMissing()) return;
    final captchaToken = spendCaptcha();
    setState(() {
      _isResending = true;
      _resendError = null;
    });
    final controller = ref.read(authControllerProvider.notifier);
    controller.clearError();
    final request = widget.request;
    final failure = request.isSignup
        ? await controller.sendSignupOtp(
            phone: request.phone,
            fullName: request.fullName!,
            captchaToken: captchaToken,
          )
        : await controller.sendPhoneOtp(
            request.phone,
            captchaToken: captchaToken,
          );
    if (!mounted) return;
    setState(() {
      _isResending = false;
      _resendError = failure?.userMessage;
    });
    if (failure is OtpCooldownFailure) {
      // The earlier code is still valid; just wait out the server cooldown.
      _startCooldown(failure.retryAfterSeconds);
    } else if (failure == null) {
      _codeController.clear();
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent.')),
      );
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(RouteNames.login);
    }
  }

  String get _displayPhone {
    final phone = widget.request.phone;
    for (final country in AuthCountry.all) {
      if (phone.startsWith(country.dialCode)) {
        final digits = phone.substring(country.dialCode.length);
        if (digits.length == 10) {
          return '${country.dialCode} ${digits.substring(0, 5)} ${digits.substring(5)}';
        }
        return '${country.dialCode} $digits';
      }
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final authState = auth.value ?? const AuthState.unauthenticated();
    final error = captchaError ?? _resendError ?? authState.errorMessage;

    // Content is anchored to the top and the CTA + footer to the bottom, so
    // spare height on tall phones opens up between them instead of above
    // the header. SliverFillRemaining still scrolls once the keyboard is up.
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthTopBar(onBack: _back),
                        const SizedBox(height: AppSpacing.md),
                        const AuthHeroCard(
                          badgeLabel: 'VERIFY',
                          badgeIcon: Icons.sms_outlined,
                          size: 120,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AuthHeading(
                          title: 'Enter Code',
                          subtitle: const Text(
                            'We sent a 6-digit verification code to',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: _PhoneChip(
                            phone: _displayPhone,
                            onEdit: authState.isSubmitting ? null : _back,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _OtpBoxes(
                          controller: _codeController,
                          focusNode: _codeFocus,
                          length: _codeLength,
                          hasError: authState.errorMessage != null,
                          enabled: !authState.isSubmitting,
                          onChanged: (value) {
                            if (authState.errorMessage != null) {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .clearError();
                            }
                            if (value.length == _codeLength) _verify();
                          },
                        ),
                        if (error != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          AuthInlineError(message: error),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        // Resend sends a new OTP, so it needs a fresh token;
                        // the check appears once the cooldown has ended.
                        if (_secondsLeft == 0) ...[
                          TurnstileWidget(
                            action: widget.request.isSignup
                                ? 'signup'
                                : 'login',
                            controller: turnstile,
                            onToken: onCaptcha,
                          ),
                          if (captchaEnabled)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                        _ResendRow(
                          secondsLeft: _secondsLeft,
                          isResending: _isResending,
                          onResend: authState.isSubmitting ? null : _resend,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Spacer(),
                        AuthGradientButton(
                          label: widget.request.isSignup
                              ? 'Verify & Create Account'
                              : 'Verify & Log In',
                          isLoading: authState.isSubmitting,
                          onPressed: _verify,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const AuthSecurityFooter(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The destination number with an inline edit affordance ("Change number").
class _PhoneChip extends StatelessWidget {
  const _PhoneChip({required this.phone, required this.onEdit});

  final String phone;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Semantics(
      button: true,
      label: '$phone, change number',
      excludeSemantics: true,
      child: Material(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.primary100,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_iphone_rounded,
                  size: 18,
                  color: isDark ? AppColors.primary200 : AppColors.primary600,
                ),
                const SizedBox(width: 6),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.onSurface(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: isDark ? AppColors.primary200 : AppColors.primary600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Didn't receive the code?" with a countdown pill, then a Resend action.
class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.secondsLeft,
    required this.isResending,
    required this.onResend,
  });

  final int secondsLeft;
  final bool isResending;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedText(context);
    final minutes = secondsLeft ~/ 60;
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      children: [
        Text(
          "Didn't receive the code?",
          style: TextStyle(fontSize: 14, color: muted),
        ),
        if (secondsLeft > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface(context),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 14, color: muted),
                const SizedBox(width: 4),
                Text(
                  'Resend in $minutes:$seconds',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          )
        else
          TextButton(
            onPressed: isResending ? null : onResend,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              isResending ? 'Sending…' : 'Resend code',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

/// Six visual digit boxes backed by one invisible text field, so paste and
/// SMS autofill (`oneTimeCode`) work natively.
class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.hasError,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Verification code',
      textField: true,
      child: GestureDetector(
        onTap: focusNode.requestFocus,
        child: Stack(
          children: [
            Opacity(
              opacity: 0,
              child: SizedBox(
                height: 60,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(length),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
            IgnorePointer(
              child: ListenableBuilder(
                listenable: Listenable.merge([controller, focusNode]),
                builder: (context, _) {
                  final code = controller.text;
                  return Row(
                    children: [
                      for (var i = 0; i < length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _OtpBox(
                            digit: i < code.length ? code[i] : '',
                            isActive:
                                focusNode.hasFocus &&
                                (i == code.length ||
                                    (i == length - 1 && code.length == length)),
                            hasError: hasError,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.isActive,
    required this.hasError,
  });

  final String digit;
  final bool isActive;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.destructive
        : isActive
        ? AppColors.primary
        : AppColors.border(context).withValues(alpha: 0.5);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
      ),
      child: Text(
        digit,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface(context),
        ),
      ),
    );
  }
}
