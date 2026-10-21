import 'dart:async';

import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/auth/presentation/state/auth_state.dart';
import 'package:doctylia_app/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.phone});

  /// E.164 number the code was sent to.
  final String phone;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
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

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
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
        .verifyPhoneOtp(phone: widget.phone, token: code);
    if (!mounted) return;
    if (ref.read(authControllerProvider).value?.errorMessage != null) {
      _codeController.clear();
      _codeFocus.requestFocus();
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _resendError = null;
    });
    final controller = ref.read(authControllerProvider.notifier);
    controller.clearError();
    final error = await controller.sendPhoneOtp(widget.phone);
    if (!mounted) return;
    setState(() {
      _isResending = false;
      _resendError = error;
    });
    if (error == null) {
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
    for (final country in AuthCountry.all) {
      if (widget.phone.startsWith(country.dialCode)) {
        final digits = widget.phone.substring(country.dialCode.length);
        if (digits.length == 10) {
          return '${country.dialCode} ${digits.substring(0, 5)} ${digits.substring(5)}';
        }
        return '${country.dialCode} $digits';
      }
    }
    return widget.phone;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final authState = auth.value ?? const AuthState.unauthenticated();
    final error = _resendError ?? authState.errorMessage;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTopBar(onBack: _back),
                  const SizedBox(height: AppSpacing.lg),
                  const AuthHeroCard(
                    badgeLabel: 'VERIFY',
                    badgeIcon: Icons.sms_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AuthHeading(
                    title: 'Enter Code',
                    subtitle: Text.rich(
                      TextSpan(
                        text: 'We sent a 6-digit code to\n',
                        children: [
                          TextSpan(
                            text: _displayPhone,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: authState.isSubmitting ? null : _back,
                      child: const Text('Change number'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _OtpBoxes(
                    controller: _codeController,
                    focusNode: _codeFocus,
                    length: _codeLength,
                    hasError: authState.errorMessage != null,
                    enabled: !authState.isSubmitting,
                    onChanged: (value) {
                      if (authState.errorMessage != null) {
                        ref.read(authControllerProvider.notifier).clearError();
                      }
                      if (value.length == _codeLength) _verify();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: _secondsLeft > 0
                        ? Text(
                            'Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.mutedText(context),
                            ),
                          )
                        : TextButton(
                            onPressed: _isResending || authState.isSubmitting
                                ? null
                                : _resend,
                            child: Text(
                              _isResending ? 'Sending…' : 'Resend code',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (error != null) ...[
                    AuthInlineError(message: error),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AuthGradientButton(
                    label: 'Verify & Log In',
                    isLoading: authState.isSubmitting,
                    onPressed: _verify,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const AuthSecurityFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
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
