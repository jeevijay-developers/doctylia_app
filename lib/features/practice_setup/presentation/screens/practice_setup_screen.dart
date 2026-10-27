import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:doctylia_app/features/practice_setup/domain/entities/india_states_cities.dart';
import 'package:doctylia_app/features/practice_setup/domain/entities/practice_setup.dart';
import 'package:doctylia_app/features/practice_setup/presentation/providers/practice_setup_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-time practice setup for new doctors, ported from the web's
/// /onboarding wizard: 1 Your Details → 2 Your Clinic → 3 Go Live (review)
/// → success. The router holds a doctor here until
/// `profiles.onboarding_completed` is true.
class PracticeSetupScreen extends ConsumerStatefulWidget {
  const PracticeSetupScreen({super.key});

  @override
  ConsumerState<PracticeSetupScreen> createState() =>
      _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends ConsumerState<PracticeSetupScreen> {
  static const _steps = [
    (Icons.medical_services_outlined, 'Your Details'),
    (Icons.apartment_rounded, 'Your Clinic'),
    (Icons.auto_awesome_rounded, 'Go Live'),
  ];

  final _detailsKey = GlobalKey<FormState>();
  final _clinicKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _fullName = TextEditingController();
  final _specializationOther = TextEditingController();
  final _qualifications = TextEditingController();
  final _experience = TextEditingController();
  final _fee = TextEditingController();
  final _clinicName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String? _specialization;
  String? _state;
  String? _city;

  int _step = 1;
  bool _saving = false;
  bool _leaving = false;
  String? _error;
  String? _slug;

  @override
  void initState() {
    super.initState();
    // Prefill like the web: name from the profile (set at signup), and the
    // verified login number as the clinic phone.
    _fullName.text = ref.read(doctorProfileProvider)?.fullName?.trim() ?? '';
    _phone.text =
        ref.read(practiceSetupRepositoryProvider).signedInMobile() ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _specializationOther,
      _qualifications,
      _experience,
      _fee,
      _clinicName,
      _phone,
      _address,
    ]) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  String get _resolvedSpecialization => _specialization == 'Other'
      ? (_specializationOther.text.trim().isEmpty
            ? 'Other'
            : _specializationOther.text.trim())
      : _specialization ?? '';

  void _goTo(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _next() {
    final form = _step == 1 ? _detailsKey : _clinicKey;
    if (!(form.currentState?.validate() ?? false)) return;
    _goTo(_step + 1);
  }

  Future<void> _goLive() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(practiceSetupRepositoryProvider)
        .complete(
          PracticeSetupDetails(
            fullName: _fullName.text.trim(),
            specialization: _resolvedSpecialization,
            qualifications: _qualifications.text.trim(),
            experienceYears: int.tryParse(_experience.text) ?? 0,
            consultationFee: int.tryParse(_fee.text) ?? 0,
            clinicName: _clinicName.text.trim(),
            state: _state!,
            city: _city!,
            phone: normalizeIndianMobile(_phone.text)!,
            address: _address.text.trim(),
          ),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (slug) {
        _slug = slug;
        _saving = false;
        _goTo(4);
      },
      onFailure: (failure) => setState(() {
        _saving = false;
        _error = failure.userMessage;
      }),
    );
  }

  /// Reloads the profile; with onboarding_completed now true the router
  /// moves on to the dashboard.
  Future<void> _toDashboard() async {
    setState(() => _leaving = true);
    final error = await ref
        .read(authControllerProvider.notifier)
        .refreshDoctorProfile();
    if (!mounted || error == null) return;
    setState(() => _leaving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _viewWebsite() async {
    final opened = await ref
        .read(externalLinkServiceProvider)
        .open(Uri.parse('https://doctylia.com/dr/$_slug'));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your website.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // System back steps back through the wizard instead of leaving it.
      canPop: _step == 1 || _step == 4,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _goTo(_step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                children: [
                  _header(),
                  if (_step < 4) ...[
                    const SizedBox(height: AppSpacing.md),
                    _Stepper(step: _step, steps: _steps),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _Card(
                        child: switch (_step) {
                          1 => _detailsStep(),
                          2 => _clinicStep(),
                          3 => _reviewStep(),
                          _ => _successStep(),
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: AppColors.subtleText(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Your data is secure & encrypted',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.subtleText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final leading = switch (_step) {
      1 => TextButton.icon(
        onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Log out'),
      ),
      2 || 3 => TextButton.icon(
        onPressed: _saving ? null : () => _goTo(_step - 1),
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
        label: const Text('Back'),
      ),
      _ => const SizedBox(height: 40),
    };
    return Row(
      children: [
        leading,
        Expanded(
          child: Text(
            _step < 4 ? 'Setup your practice' : 'All set',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText(context),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 1 ─────────────────────────────────────────────────────────────
  Widget _detailsStep() {
    return Form(
      key: _detailsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeading(
            icon: Icons.medical_services_outlined,
            color: AppColors.primary,
            title: 'Tell Us About You',
            subtitle: 'Your professional details',
          ),
          const _Label('Full Name', required: true),
          TextFormField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Rahul Sharma'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Please enter your full name' : null,
          ),
          const _Gap(),
          const _Label('Specialization', required: true),
          DropdownButtonFormField<String>(
            initialValue: _specialization,
            isExpanded: true,
            menuMaxHeight: 360,
            hint: const Text('Select specialization'),
            items: [
              for (final s in practiceSpecializations)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => _specialization = v),
            validator: (v) =>
                v == null ? 'Please select your specialization' : null,
          ),
          if (_specialization == 'Other') ...[
            const _Gap(),
            const _Label(
              'Please specify your specialization',
              icon: Icons.medical_services_outlined,
            ),
            TextFormField(
              controller: _specializationOther,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Sports Medicine',
              ),
            ),
          ],
          const _Gap(),
          const _Label(
            'Qualifications',
            icon: Icons.school_outlined,
            required: true,
          ),
          TextFormField(
            controller: _qualifications,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'MBBS, MD (Cardiology)',
            ),
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Please enter your qualifications'
                : null,
          ),
          const _Gap(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Label('Years of Experience', required: true),
                    TextFormField(
                      controller: _experience,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      decoration: const InputDecoration(hintText: '15'),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Please enter years of experience'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Label('Consultation Fee (₹)', required: true),
                    TextFormField(
                      controller: _fee,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        hintText: '500',
                        prefixText: '₹ ',
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Please enter your consultation fee'
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthGradientButton(label: 'Next', onPressed: _next),
        ],
      ),
    );
  }

  // ── Step 2 ─────────────────────────────────────────────────────────────
  Widget _clinicStep() {
    return Form(
      key: _clinicKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeading(
            icon: Icons.apartment_rounded,
            color: AppColors.teal,
            title: 'Your Clinic',
            subtitle: 'Where do you practice?',
          ),
          const _Label(
            'Clinic / Hospital Name',
            icon: Icons.apartment_rounded,
            required: true,
          ),
          TextFormField(
            controller: _clinicName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Sharma Heart Care'),
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Please enter your clinic/hospital name'
                : null,
          ),
          const _Gap(),
          const _Label('State', icon: Icons.place_outlined, required: true),
          DropdownButtonFormField<String>(
            initialValue: _state,
            isExpanded: true,
            menuMaxHeight: 360,
            hint: const Text('Select state'),
            items: [
              for (final s in indiaStates)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() {
              _state = v;
              _city = null;
            }),
            validator: (v) => v == null ? 'Please select your state' : null,
          ),
          const _Gap(),
          const _Label('City', icon: Icons.place_outlined, required: true),
          DropdownButtonFormField<String>(
            // Rebuilt per state so a stale city never lingers.
            key: ValueKey(_state),
            initialValue: _city,
            isExpanded: true,
            menuMaxHeight: 360,
            hint: Text(_state == null ? 'Select a state first' : 'Select city'),
            items: [
              for (final c in citiesForState(_state))
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: _state == null ? null : (v) => setState(() => _city = v),
            validator: (v) => v == null ? 'Please select your city' : null,
          ),
          const _Gap(),
          const _Label(
            'Phone Number',
            icon: Icons.phone_outlined,
            required: true,
          ),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+\s-]')),
            ],
            decoration: const InputDecoration(
              hintText: '98765 43210',
              prefixText: '+91  ',
            ),
            validator: (v) {
              if ((v ?? '').trim().isEmpty) {
                return 'Please enter your phone number';
              }
              return normalizeIndianMobile(v!) == null
                  ? 'Enter a valid 10-digit Indian mobile number (starting with 6/7/8/9)'
                  : null;
            },
          ),
          const _Gap(),
          const _Label('Full Address', required: true),
          TextFormField(
            controller: _address,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Building, Street, Area, City',
            ),
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Please enter your full address'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          _BackNextRow(
            onBack: () => _goTo(1),
            primary: AuthGradientButton(label: 'Next', onPressed: _next),
          ),
        ],
      ),
    );
  }

  // ── Step 3 ─────────────────────────────────────────────────────────────
  Widget _reviewStep() {
    final name = _fullName.text.trim();
    final city = _city ?? '';
    final rows = [
      ('Name', name),
      ('Specialization', _resolvedSpecialization),
      ('Qualifications', _qualifications.text.trim()),
      ('Experience', '${_experience.text} years'),
      ('Consultation Fee', '₹${_fee.text}'),
      ('Clinic', '${_clinicName.text.trim()}, $city'),
      ('Phone', '+91 ${normalizeIndianMobile(_phone.text) ?? _phone.text}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeading(
          icon: Icons.auto_awesome_rounded,
          color: AppColors.success,
          title: "You're Almost Done!",
          subtitle: 'Review your details and go live',
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.secondarySurface(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              for (final (i, (label, value)) in rows.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.mutedText(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        value.trim().isEmpty ? '—' : value,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _WebsitePreview(
          name: name,
          specialization: _resolvedSpecialization,
          clinic: '${_clinicName.text.trim()}, $city',
          slug: practiceSlugFor(name),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          AuthInlineError(message: _error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        _BackNextRow(
          onBack: _saving ? null : () => _goTo(2),
          primary: AuthGradientButton(
            label: 'Go Live!',
            isLoading: _saving,
            onPressed: _goLive,
          ),
        ),
      ],
    );
  }

  // ── Success ────────────────────────────────────────────────────────────
  Widget _successStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 52,
                color: AppColors.success,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const AuthHeading(
          title: 'Your Website is Live! 🎉',
          subtitle: Text(
            'Your 7-day free trial has started. Explore your dashboard to customize everything.',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AuthGradientButton(
          label: 'Go to Dashboard',
          isLoading: _leaving,
          onPressed: _toDashboard,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _slug == null ? null : _viewWebsite,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          icon: const Icon(Icons.language_rounded, size: 20),
          label: const Text(
            'View My Website',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

// ── Building blocks ──────────────────────────────────────────────────────

/// Numbered steps joined by lines: done = green check, current = blue.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.step, required this.steps});

  final int step;
  final List<(IconData, String)> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            flex: 3,
            child: _StepDot(index: i + 1, step: step, label: steps[i].$2),
          ),
          if (i < steps.length - 1)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(top: 17),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 2,
                  decoration: BoxDecoration(
                    color: step > i + 1
                        ? AppColors.success
                        : AppColors.border(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.step,
    required this.label,
  });

  final int index;
  final int step;
  final String label;

  @override
  Widget build(BuildContext context) {
    final done = step > index;
    final current = step == index;
    final background = done
        ? AppColors.success
        : current
        ? AppColors.primary600
        : AppColors.secondarySurface(context);
    final foreground = done || current
        ? Colors.white
        : AppColors.mutedText(context);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: done
              ? Icon(Icons.check_rounded, size: 20, color: foreground)
              : Text(
                  '$index',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            color: current || done
                ? AppColors.onSurface(context)
                : AppColors.mutedText(context),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.border(context).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context, alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.mutedText(context)),
          ),
        ],
      ),
    );
  }
}

/// Field label with optional leading icon and a red asterisk when required.
class _Label extends StatelessWidget {
  const _Label(this.text, {this.icon, this.required = false});

  final String text;
  final IconData? icon;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.onSurface(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.mutedText(context)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text.rich(
              TextSpan(
                text: text,
                children: [
                  if (required)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.destructive),
                    ),
                ],
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: AppSpacing.md);
}

class _BackNextRow extends StatelessWidget {
  const _BackNextRow({required this.onBack, required this.primary});

  final VoidCallback? onBack;
  final Widget primary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text(
              'Back',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(flex: 2, child: primary),
      ],
    );
  }
}

/// The web's "YOUR WEBSITE PREVIEW" mock card.
class _WebsitePreview extends StatelessWidget {
  const _WebsitePreview({
    required this.name,
    required this.specialization,
    required this.clinic,
    required this.slug,
  });

  final String name;
  final String specialization;
  final String clinic;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedText(context);
    final initial = name.isEmpty ? 'D' : name[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language_rounded, size: 14, color: muted),
              const SizedBox(width: 6),
              Text(
                'YOUR WEBSITE PREVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Doctor Name' : name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface(context),
                            ),
                          ),
                          Text(
                            specialization.isEmpty
                                ? 'Specialization'
                                : specialization,
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                          Text(
                            clinic,
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    _PreviewChip('Book Appointment', AppColors.primary600),
                    _PreviewChip('Services', AppColors.teal),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'doctylia.com/dr/$slug',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
