import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/doctylia_brand_mark.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() {
    return _ForgotPasswordScreenState();
  }
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(_emailController.text);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
      _sent = error == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.goNamed(RouteNames.login),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to login',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _sent ? _confirmation(context) : _form(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: DoctyliaBrandMark(size: 52, showName: false)),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Reset your password',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enter your account email and we’ll send you a reset link.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
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
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }

  Widget _confirmation(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 72),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Check your email',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'If an account exists for ${_emailController.text.trim()}, '
          'a password reset link is on its way.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () => context.goNamed(RouteNames.login),
          child: const Text('Back to login'),
        ),
      ],
    );
  }
}
