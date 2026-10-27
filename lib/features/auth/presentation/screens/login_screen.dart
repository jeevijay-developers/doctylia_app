import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/security/turnstile.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:doctylia_app/features/auth/presentation/screens/signup_screen.dart';
import 'package:doctylia_app/features/auth/presentation/state/auth_state.dart';
import 'package:doctylia_app/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TurnstileGate<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AuthCountry _country = AuthCountry.india;
  bool _useEmail = false;
  bool _obscurePassword = true;
  bool _isSendingOtp = false;
  String? _otpError;
  bool _showSignupLink = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (captchaMissing()) return;
    final phone = _country.toE164(_phoneController.text);
    setState(() {
      _isSendingOtp = true;
      _otpError = null;
      _showSignupLink = false;
    });
    final failure = await ref
        .read(authControllerProvider.notifier)
        .sendPhoneOtp(phone, captchaToken: spendCaptcha());
    if (!mounted) return;
    setState(() {
      _isSendingOtp = false;
      _otpError = failure?.userMessage;
      _showSignupLink = failure is PhoneNotRegisteredFailure;
    });
    if (failure == null) {
      context.pushNamed(
        RouteNames.otpVerify,
        extra: OtpRequest(phone: phone).toExtra(),
      );
    }
  }

  Future<void> _signInWithEmail() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (captchaMissing()) return;
    await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
          captchaToken: spendCaptcha(),
        );
  }

  void _toggleMethod() {
    ref.read(authControllerProvider.notifier).clearError();
    _formKey.currentState?.reset();
    setState(() {
      _useEmail = !_useEmail;
      _otpError = null;
      captchaError = null;
      _showSignupLink = false;
    });
  }

  void _onBack() {
    if (_useEmail) {
      _toggleMethod();
    } else {
      context.goNamed(RouteNames.onboarding);
    }
  }

  /// In-app signup. Like the web form, the typed number carries over.
  void _openSignup() {
    ref.read(authControllerProvider.notifier).clearError();
    setState(() {
      _otpError = null;
      _showSignupLink = false;
    });
    context.pushNamed(
      RouteNames.signup,
      extra: SignupPrefill(
        country: _country,
        digits: _phoneController.text,
      ).toExtra(),
    );
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
    final auth = ref.watch(authControllerProvider);
    final authState = auth.value ?? const AuthState.unauthenticated();
    final isBusy = _isSendingOtp || authState.isSubmitting;
    final error =
        captchaError ?? (_useEmail ? authState.errorMessage : _otpError);

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
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthTopBar(onBack: _onBack),
                      const SizedBox(height: AppSpacing.lg),
                      AuthHeroCard(
                        badgeLabel: _useEmail ? 'SECURE LOGIN' : 'FAST OTP',
                        badgeIcon: Icons.verified_user_rounded,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AuthHeading(
                        title: 'Welcome Back',
                        subtitle: Text(
                          _useEmail
                              ? 'Log in to your dashboard with your registered email and password.'
                              : 'Log in to your dashboard with your verified phone number.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_useEmail)
                        ..._buildEmailFields(authState)
                      else
                        ..._buildPhoneFields(),
                      const SizedBox(height: AppSpacing.lg),
                      const _FeatureHighlights(),
                      const SizedBox(height: AppSpacing.lg),
                      TurnstileWidget(
                        action: 'login',
                        controller: turnstile,
                        onToken: onCaptcha,
                      ),
                      if (captchaEnabled) const SizedBox(height: AppSpacing.md),
                      if (error != null) ...[
                        AuthInlineError(message: error),
                        if (!_useEmail && _showSignupLink)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _openSignup,
                              child: const Text(
                                'Sign up instead',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AuthGradientButton(
                        label: _useEmail ? 'Log In' : 'Send OTP',
                        isLoading: isBusy,
                        onPressed: _useEmail ? _signInWithEmail : _sendOtp,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.mutedText(context),
                            ),
                          ),
                          TextButton(
                            onPressed: _openSignup,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                            ),
                            child: const Text(
                              'Sign Up Free',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: TextButton(
                          onPressed: isBusy ? null : _toggleMethod,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.isDark(context)
                                ? const Color(0xFF5EEAD4)
                                : const Color(0xFF0F766E),
                          ),
                          child: Text(
                            _useEmail
                                ? 'Log in with Mobile Number'
                                : 'Doctor / Clinic Staff Login',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const AuthSecurityFooter(),
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

  List<Widget> _buildPhoneFields() {
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              'Mobile Number',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface(context),
              ),
            ),
          ),
          const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary600),
          const Flexible(
            child: Text(
              'Instant Sign-in',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary600,
              ),
            ),
          ),
        ],
      ),
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
        text: 'A 6-digit confirmation code will be sent via SMS',
      ),
    ];
  }

  List<Widget> _buildEmailFields(AuthState authState) {
    return [
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Email',
          hintText: 'doctor@example.com',
          prefixIcon: Icon(Icons.mail_outline_rounded),
        ),
        validator: (value) {
          final email = value?.trim() ?? '';
          if (!email.contains('@') || !email.contains('.')) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        onFieldSubmitted: (_) => _signInWithEmail(),
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        validator: (value) {
          if ((value ?? '').isEmpty) return 'Enter your password';
          return null;
        },
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: authState.isSubmitting
              ? null
              : () => context.goNamed(RouteNames.forgotPassword),
          child: const Text('Forgot password?'),
        ),
      ),
    ];
  }
}

class _FeatureHighlights extends StatelessWidget {
  const _FeatureHighlights();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _FeatureItem(
              icon: Icons.videocam_outlined,
              title: 'Video Consults',
              subtitle: 'HD encrypted',
            ),
          ),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _FeatureItem(
              icon: Icons.assignment_outlined,
              title: 'Rx Delivery',
              subtitle: 'Fast door dispatch',
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary600),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface(context),
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedText(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
