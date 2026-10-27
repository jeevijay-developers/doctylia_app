import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/security/turnstile.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:doctylia_app/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Number already typed on the login screen, carried into signup (the web
/// form keeps the phone when switching between login and signup modes).
///
/// Travels as a JSON-safe map, like [OtpRequest].
class SignupPrefill {
  const SignupPrefill({required this.country, required this.digits});

  static SignupPrefill? fromExtra(Object? extra) {
    if (extra is! Map) return null;
    final dialCode = extra['dialCode'];
    final digits = extra['digits'];
    if (dialCode is! String || digits is! String) return null;
    final country = AuthCountry.all
        .where((c) => c.dialCode == dialCode)
        .firstOrNull;
    return SignupPrefill(country: country ?? AuthCountry.india, digits: digits);
  }

  Map<String, String> toExtra() => {
    'dialCode': country.dialCode,
    'digits': digits,
  };

  final AuthCountry country;
  final String digits;
}

/// In-app doctor signup, mirroring the web Auth page's signup mode
/// (PhoneOtpForm mode="signup"): Full Name + Phone Number → Send OTP, then
/// the shared code screen creates the account on verification.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, this.prefill});

  final SignupPrefill? prefill;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with TurnstileGate<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final TextEditingController _phoneController;
  late AuthCountry _country;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _country = widget.prefill?.country ?? AuthCountry.india;
    _phoneController = TextEditingController(text: widget.prefill?.digits);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (captchaMissing()) return;
    final phone = _country.toE164(_phoneController.text);
    final fullName = _nameController.text.trim();
    setState(() {
      _isSending = true;
      _error = null;
    });
    final failure = await ref
        .read(authControllerProvider.notifier)
        .sendSignupOtp(
          phone: phone,
          fullName: fullName,
          captchaToken: spendCaptcha(),
        );
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _error = failure?.userMessage;
    });
    if (failure == null) {
      context.pushNamed(
        RouteNames.otpVerify,
        extra: OtpRequest(phone: phone, fullName: fullName).toExtra(),
      );
    }
  }

  void _toLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(RouteNames.login);
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showAuthCountryPicker(context, selected: _country);
    if (picked == null || picked == _country) return;
    setState(() {
      _country = picked;
      if (_phoneController.text.length > picked.maxDigits) {
        _phoneController.text = _phoneController.text.substring(
          0,
          picked.maxDigits,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthTopBar(onBack: _toLogin),
                            const SizedBox(height: AppSpacing.md),
                            const AuthHeroCard(
                              badgeLabel: 'FREE TRIAL',
                              badgeIcon: Icons.workspace_premium_rounded,
                              size: 120,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const AuthHeading(
                              title: 'Start Your Free Trial',
                              subtitle: Text('7 days free'),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _FieldLabel('Full Name'),
                            const SizedBox(height: AppSpacing.xs),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                hintText: 'Dr. Rahul Sharma',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) {
                                final name = value?.trim() ?? '';
                                if (name.isEmpty) return 'Enter your full name';
                                if (name.length < 2) {
                                  return 'Enter your full name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _FieldLabel('Phone Number'),
                            const SizedBox(height: AppSpacing.xs),
                            AuthPhoneField(
                              controller: _phoneController,
                              country: _country,
                              onPickCountry: _pickCountry,
                              onSubmitted: _sendOtp,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const AuthHint(
                              icon: Icons.check_circle_outline_rounded,
                              text:
                                  'A 6-digit confirmation code will be sent via SMS',
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TurnstileWidget(
                              action: 'signup',
                              controller: turnstile,
                              onToken: onCaptcha,
                            ),
                            if (captchaEnabled)
                              const SizedBox(height: AppSpacing.md),
                            if ((captchaError ?? _error) != null) ...[
                              AuthInlineError(
                                message: (captchaError ?? _error)!,
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            AuthGradientButton(
                              label: 'Send OTP',
                              isLoading: _isSending,
                              onPressed: _sendOtp,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Already have an account?',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.mutedText(context),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isSending ? null : _toLogin,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs,
                                    ),
                                  ),
                                  child: const Text(
                                    'Log In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const _TrustPoints(),
                            const Spacer(),
                            const SizedBox(height: AppSpacing.lg),
                            const AuthSecurityFooter(),
                          ],
                        ),
                      ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface(context),
      ),
    );
  }
}

/// The web Auth page's trust points ("Join 10,000+ doctors…").
class _TrustPoints extends StatelessWidget {
  const _TrustPoints();

  static const _points = [
    (Icons.groups_rounded, 'Join 10,000+ doctors across India'),
    (Icons.bolt_rounded, 'Go live in under 5 minutes'),
    (Icons.verified_user_rounded, '7-day free trial · No credit card'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          for (final (i, (icon, text)) in _points.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary600),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface(context),
                    ),
                  ),
                ),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppColors.success,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
