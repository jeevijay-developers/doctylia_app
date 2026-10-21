import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/auth/presentation/state/auth_state.dart';
import 'package:doctylia_app/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AuthCountry _country = AuthCountry.india;
  bool _useEmail = false;
  bool _obscurePassword = true;
  bool _isSendingOtp = false;
  String? _otpError;

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
    final phone = _country.toE164(_phoneController.text);
    setState(() {
      _isSendingOtp = true;
      _otpError = null;
    });
    final error = await ref
        .read(authControllerProvider.notifier)
        .sendPhoneOtp(phone);
    if (!mounted) return;
    setState(() {
      _isSendingOtp = false;
      _otpError = error;
    });
    if (error == null) {
      context.pushNamed(RouteNames.otpVerify, extra: phone);
    }
  }

  Future<void> _signInWithEmail() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  void _toggleMethod() {
    ref.read(authControllerProvider.notifier).clearError();
    _formKey.currentState?.reset();
    setState(() {
      _useEmail = !_useEmail;
      _otpError = null;
    });
  }

  void _onBack() {
    if (_useEmail) {
      _toggleMethod();
    } else {
      context.goNamed(RouteNames.onboarding);
    }
  }

  Future<void> _openSignup() async {
    final opened = await ref
        .read(externalLinkServiceProvider)
        .open(Uri.parse('https://doctylia.com/auth?mode=signup'));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open doctylia.com.')),
      );
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<AuthCountry>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final country in AuthCountry.all)
              ListTile(
                leading: Text(
                  country.flag,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(country.name),
                trailing: Text(
                  country.dialCode,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                selected: country == _country,
                onTap: () => Navigator.of(context).pop(country),
              ),
          ],
        ),
      ),
    );
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
    final error = _useEmail ? authState.errorMessage : _otpError;

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
                      if (error != null) ...[
                        AuthInlineError(message: error),
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
          Text(
            'Mobile Number',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface(context),
            ),
          ),
          const Spacer(),
          const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary600),
          const Text(
            'Instant Sign-in',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primary600,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      _PhoneField(
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

/// Country prefix (flag, dial code, chevron) + national number input.
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.country,
    required this.onPickCountry,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final AuthCountry country;
  final VoidCallback onPickCountry;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide.none,
    );
    return FormField<String>(
      validator: (_) => country.validate(controller.text),
      builder: (field) {
        final hasError = field.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: hasError
                      ? AppColors.destructive
                      : AppColors.border(context).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: onPickCountry,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.lg),
                    ),
                    child: Semantics(
                      button: true,
                      label: 'Country code ${country.dialCode}, change',
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Text(
                              country.flag,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              country.dialCode,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface(context),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: AppColors.mutedText(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1.5,
                    height: 26,
                    color: AppColors.primary200,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.telephoneNumberNational,
                      ],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(country.maxDigits),
                      ],
                      onChanged: (value) {
                        field.didChange(value);
                        if (hasError) field.validate();
                      },
                      onSubmitted: (_) => onSubmitted(),
                      style: TextStyle(
                        fontSize: 18,
                        letterSpacing: 0.5,
                        color: AppColors.onSurface(context),
                      ),
                      decoration: InputDecoration(
                        hintText: '98765 43210',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          color: AppColors.subtleText(context),
                        ),
                        filled: false,
                        border: border,
                        enabledBorder: border,
                        focusedBorder: border,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: AppSpacing.sm),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.destructive,
                  ),
                ),
              ),
          ],
        );
      },
    );
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
