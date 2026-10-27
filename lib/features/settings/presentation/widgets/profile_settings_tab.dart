import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/platform/app_version.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/theme/theme_mode_provider.dart';
import 'package:doctylia_app/core/widgets/app_motion.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/settings/domain/entities/settings_models.dart';
import 'package:doctylia_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

InputDecoration _fieldDecoration(
  String label, {
  bool profileStyle = false,
  String? prefixText,
  String? suffixText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) => InputDecoration(
  labelText: label,
  prefixText: prefixText,
  prefixIcon: prefixIcon,
  suffixText: suffixText,
  suffixIcon: suffixIcon,
  suffixStyle: const TextStyle(
    color: AppColors.textLight,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  ),
  isDense: profileStyle,
  filled: !profileStyle,
  fillColor: profileStyle ? null : AppColors.primary.withValues(alpha: 0.035),
  labelStyle: profileStyle
      ? const TextStyle(color: AppColors.textMuted, fontSize: 12)
      : null,
  contentPadding: profileStyle
      ? const EdgeInsets.symmetric(horizontal: 14, vertical: 14)
      : null,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(profileStyle ? 14 : AppRadius.sm),
    borderSide: profileStyle
        ? const BorderSide(color: AppColors.lightBorder)
        : BorderSide.none,
  ),
  enabledBorder: profileStyle
      ? OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        )
      : null,
  focusedBorder: profileStyle
      ? OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.3),
        )
      : null,
);

/// The web's public legal pages.
abstract final class _LegalLinks {
  static final privacy = Uri.parse('https://doctylia.com/privacy');
  static final terms = Uri.parse('https://doctylia.com/terms');
  static final refunds = Uri.parse('https://doctylia.com/refund-policy');
}

/// Editable sections of the "Clinical Practice & Account" card.
enum _Editor { details, clinic, payout }

class ProfileSettingsTab extends ConsumerStatefulWidget {
  const ProfileSettingsTab({required this.snapshot, super.key});
  final SettingsSnapshot snapshot;
  @override
  ConsumerState<ProfileSettingsTab> createState() => _ProfileSettingsTabState();
}

class _ProfileSettingsTabState extends ConsumerState<ProfileSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final _practiceKey = GlobalKey();
  late final Map<String, TextEditingController> _c;
  late bool _gst;
  late PayoutMethod _method;
  bool _saving = false;
  bool _savingPayout = false;

  /// Expanded editors. Collapsed ones stay mounted (hidden), so form
  /// validation still covers every field.
  final Set<_Editor> _open = {};

  @override
  void initState() {
    super.initState();
    final p = widget.snapshot.profile;
    final bank = widget.snapshot.payoutAccount;
    _gst = p.gstRegistered;
    _method = bank?.method ?? PayoutMethod.bank;
    _c = {
      'name': TextEditingController(text: _withoutDoctorPrefix(p.fullName)),
      'specialization': TextEditingController(text: p.specialization),
      'qualifications': TextEditingController(text: p.qualifications),
      'experience': TextEditingController(text: '${p.experienceYears}'),
      'phone': TextEditingController(text: p.phone),
      'fee': TextEditingController(text: p.consultationFee.toStringAsFixed(0)),
      'registration': TextEditingController(text: p.registrationNumber),
      'clinic': TextEditingController(text: p.clinicName),
      'city': TextEditingController(text: p.city),
      'state': TextEditingController(text: p.state),
      'address': TextEditingController(text: p.address),
      'email': TextEditingController(text: p.clinicEmail),
      'gstin': TextEditingController(text: p.gstin),
      'holder': TextEditingController(text: bank?.accountHolderName ?? ''),
      'account': TextEditingController(text: bank?.accountNumber ?? ''),
      'ifsc': TextEditingController(text: bank?.ifsc ?? ''),
      'upi': TextEditingController(text: bank?.upiId ?? ''),
    };
  }

  @override
  void dispose() {
    for (final controller in _c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  void _toggle(_Editor editor) => setState(() {
    if (!_open.remove(editor)) _open.add(editor);
  });

  /// Header "Edit profile": open the details editor and bring it into view.
  void _editProfile() {
    setState(() => _open.add(_Editor.details));
    final target = _practiceKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      // The required fields live in "Your Details" — reveal the errors.
      setState(() => _open.add(_Editor.details));
      return;
    }
    setState(() => _saving = true);
    final profile = DoctorProfileSettings(
      fullName: _withDoctorPrefix(_c['name']!.text),
      specialization: _c['specialization']!.text.trim(),
      qualifications: _c['qualifications']!.text.trim(),
      experienceYears: int.tryParse(_c['experience']!.text) ?? 0,
      phone: _c['phone']!.text.trim(),
      clinicName: _c['clinic']!.text.trim(),
      city: _c['city']!.text.trim(),
      state: _c['state']!.text.trim(),
      address: _c['address']!.text.trim(),
      consultationFee: double.tryParse(_c['fee']!.text) ?? 0,
      registrationNumber: _c['registration']!.text.trim(),
      clinicEmail: _c['email']!.text.trim(),
      gstRegistered: _gst,
      gstin: _gst ? _c['gstin']!.text.trim().toUpperCase() : '',
    );
    String? error;
    try {
      error = await ref.read(settingsProvider.notifier).saveProfile(profile);
    } on AppFailure catch (failure) {
      error = failure.userMessage;
    } catch (_) {
      error = 'The profile could not be saved. Please try again.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Profile saved.'),
        backgroundColor: error == null ? null : AppColors.destructive,
      ),
    );
  }

  Future<void> _savePayout() async {
    final account = _c['account']!.text.replaceAll(' ', '');
    final ifsc = _c['ifsc']!.text.trim().toUpperCase();
    final upi = _c['upi']!.text.trim();
    String? validation;
    if (_method == PayoutMethod.bank &&
        (!RegExp(r'^\d{9,20}$').hasMatch(account) ||
            !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc))) {
      validation = 'Enter a valid account number and IFSC.';
    }
    if (_method == PayoutMethod.upi &&
        !RegExp(r'^[\w.-]{2,}@[\w.-]{2,}$').hasMatch(upi)) {
      validation = 'Enter a valid UPI ID.';
    }
    if (validation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation)));
      return;
    }
    setState(() => _savingPayout = true);
    final error = await ref
        .read(settingsProvider.notifier)
        .savePayout(
          DoctorPayoutAccount(
            method: _method,
            accountHolderName: _c['holder']!.text.trim(),
            accountNumber: _method == PayoutMethod.bank ? account : null,
            ifsc: _method == PayoutMethod.bank ? ifsc : null,
            upiId: _method == PayoutMethod.upi ? upi : null,
            isMock: widget.snapshot.paymentMode == PaymentMode.mock,
          ),
        );
    if (mounted) {
      setState(() => _savingPayout = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ??
                (widget.snapshot.paymentMode == PaymentMode.mock
                    ? 'Payout details saved in TEST MODE.'
                    : 'Payout details saved.'),
          ),
          backgroundColor: error == null ? null : AppColors.destructive,
        ),
      );
    }
  }

  Future<void> _openClinicMap() async {
    final query =
        [
              _c['clinic']!.text,
              _c['address']!.text,
              _c['city']!.text,
              _c['state']!.text,
            ]
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .join(', ');
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add the clinic address first.')),
      );
      return;
    }
    final opened = await ref
        .read(externalLinkServiceProvider)
        .open(
          Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': query,
          }),
        );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the map.')));
    }
  }

  Future<void> _openLink(Uri uri) async {
    final opened = await ref.read(externalLinkServiceProvider).open(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the page.')));
    }
  }

  // ── Summaries shown on collapsed rows ─────────────────────────────────
  String get _detailsSummary {
    final specialization = _c['specialization']!.text.trim();
    final fee = double.tryParse(_c['fee']!.text) ?? 0;
    return [
      if (specialization.isNotEmpty) specialization,
      '₹${fee.toStringAsFixed(0)} / visit',
    ].join(' · ');
  }

  String get _clinicSummary {
    final parts = [
      _c['clinic']!.text.trim(),
      _c['city']!.text.trim(),
    ].where((value) => value.isNotEmpty);
    final base = parts.isEmpty ? 'Add your clinic address' : parts.join(' · ');
    return _gst ? '$base · GST' : base;
  }

  String get _payoutSummary {
    final saved = widget.snapshot.payoutAccount;
    if (saved == null) return 'Not set up yet';
    if (saved.method == PayoutMethod.upi) {
      return 'UPI · ${saved.upiId ?? ''}';
    }
    final number = saved.accountNumber ?? '';
    final tail = number.length > 4
        ? number.substring(number.length - 4)
        : number;
    return 'Bank account ••••$tail';
  }

  @override
  Widget build(BuildContext context) {
    final appProfile = ref.watch(doctorProfileProvider);
    final stats = ref.watch(dashboardProvider).value?.stats;
    final themeMode = ref.watch(themeModeProvider);
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final version = ref.watch(appVersionProvider).value;
    final profile = widget.snapshot.profile;
    final payoutVerified = widget.snapshot.payoutAccount?.verified == true;

    Widget enter(int index, Widget child) => AppEntrance(
      index: index,
      step: const Duration(milliseconds: 35),
      offset: const Offset(0, 0.04),
      child: child,
    );

    return DashboardShadcnScope(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            enter(
              0,
              _ProfileHeaderCard(
                profile: profile,
                subscription: widget.snapshot.subscription,
                photoUrl: appProfile?.profilePhotoUrl,
                patients: stats?.patients,
                rating: stats == null || stats.reviewCount == 0
                    ? null
                    : stats.averageRating,
                onEdit: _editProfile,
              ),
            ),
            enter(
              1,
              _GroupCard(
                key: _practiceKey,
                title: 'Clinical Practice & Account',
                rows: [
                  _ExpandableRow(
                    icon: Icons.medical_services_outlined,
                    color: DashboardTokens.tealDeep,
                    title: 'Your Details',
                    summary: _detailsSummary,
                    expanded: _open.contains(_Editor.details),
                    onToggle: () => _toggle(_Editor.details),
                    child: Column(
                      children: [
                        _field(
                          'Full Name',
                          'name',
                          validator: _required,
                          profileStyle: true,
                          prefixText: 'Dr. ',
                        ),
                        _field(
                          'Specialization',
                          'specialization',
                          validator: _required,
                          profileStyle: true,
                        ),
                        _field(
                          'Qualifications',
                          'qualifications',
                          profileStyle: true,
                          suffixText: 'Degrees',
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                'Experience (years)',
                                'experience',
                                number: true,
                                profileStyle: true,
                                suffixText: 'Yrs',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: _field(
                                'Consultation Fee (₹)',
                                'fee',
                                number: true,
                                profileStyle: true,
                                suffixText: 'INR',
                              ),
                            ),
                          ],
                        ),
                        _field(
                          'Phone',
                          'phone',
                          profileStyle: true,
                          suffixIcon: _savedSuffix(Icons.check_circle_rounded),
                        ),
                        _field(
                          'Medical Registration Number',
                          'registration',
                          profileStyle: true,
                          suffixIcon: _savedSuffix(
                            Icons.verified_user_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ExpandableRow(
                    icon: Icons.location_on_outlined,
                    color: AppColors.primary600,
                    title: 'Clinic Details',
                    summary: _clinicSummary,
                    expanded: _open.contains(_Editor.clinic),
                    onToggle: () => _toggle(_Editor.clinic),
                    child: Column(
                      children: [
                        _field(
                          'Clinic Name',
                          'clinic',
                          profileStyle: true,
                          suffixIcon: _savedSuffix(
                            Icons.check_circle_outline_rounded,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _field('City', 'city', profileStyle: true),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: _field(
                                'State',
                                'state',
                                profileStyle: true,
                              ),
                            ),
                          ],
                        ),
                        _field(
                          'Full Address',
                          'address',
                          lines: 2,
                          profileStyle: true,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _MapPinButton(onPressed: _openClinicMap),
                          ),
                        ),
                        _field(
                          'Clinic Email',
                          'email',
                          profileStyle: true,
                          prefixIcon: const Icon(
                            Icons.mail_outline_rounded,
                            size: 17,
                            color: AppColors.textLight,
                          ),
                        ),
                        _GstInvoiceControl(
                          value: _gst,
                          onChanged: (value) => setState(() => _gst = value),
                        ),
                        if (_gst) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _field('GSTIN', 'gstin', profileStyle: true),
                        ],
                      ],
                    ),
                  ),
                  _ExpandableRow(
                    icon: Icons.account_balance_outlined,
                    color: AppColors.success,
                    title: 'Bank / UPI Setup',
                    summary: _payoutSummary,
                    trailing: widget.snapshot.paymentMode == PaymentMode.mock
                        ? const _TestModeBadge()
                        : payoutVerified
                        ? const DashboardToneBadge(
                            label: 'Verified',
                            color: AppColors.success,
                            icon: Icons.verified_rounded,
                          )
                        : null,
                    expanded: _open.contains(_Editor.payout),
                    onToggle: () => _toggle(_Editor.payout),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Automatic daily payouts for practice',
                          style: TextStyle(
                            color: AppColors.subtleText(context),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const _PayoutInfoBanner(),
                        const SizedBox(height: 14),
                        _PayoutMethodSelector(
                          value: _method,
                          onChanged: (value) => setState(() => _method = value),
                        ),
                        const SizedBox(height: 16),
                        _field(
                          'Account Holder Name',
                          'holder',
                          profileStyle: true,
                        ),
                        if (_method == PayoutMethod.bank) ...[
                          _field(
                            'Account Number',
                            'account',
                            number: true,
                            profileStyle: true,
                            obscureText: true,
                            suffixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 17,
                              color: AppColors.textLight,
                            ),
                          ),
                          _field(
                            'IFSC Code',
                            'ifsc',
                            profileStyle: true,
                            suffixIcon: payoutVerified
                                ? const Icon(
                                    Icons.verified_user_outlined,
                                    size: 18,
                                    color: AppColors.success,
                                  )
                                : null,
                          ),
                        ] else
                          _field(
                            'UPI ID',
                            'upi',
                            profileStyle: true,
                            prefixIcon: const Icon(
                              Icons.smartphone_rounded,
                              size: 17,
                              color: AppColors.textLight,
                            ),
                            suffixIcon: payoutVerified
                                ? const Icon(
                                    Icons.verified_user_outlined,
                                    size: 18,
                                    color: AppColors.success,
                                  )
                                : null,
                          ),
                        shadcn.OutlineButton(
                          onPressed: _savingPayout ? null : _savePayout,
                          alignment: Alignment.center,
                          leading: const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 17,
                          ),
                          child: Text(
                            _savingPayout ? 'Saving...' : 'Save Payout Details',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                footer: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: shadcn.PrimaryButton(
                      onPressed: _saving ? null : _saveProfile,
                      alignment: Alignment.center,
                      leading: const Icon(Icons.save_rounded, size: 17),
                      child: Text(
                        _saving
                            ? 'Saving...'
                            : 'Save Profile & Clinic Settings',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            enter(
              2,
              _GroupCard(
                title: 'App Preferences',
                rows: [
                  _SettingRow(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppColors.aiPurple,
                    title: 'Dark Mode',
                    subtitle: 'Easier on the eyes during night shifts',
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setDarkMode(!isDark),
                    trailing: shadcn.Switch(
                      value: isDark,
                      onChanged: (value) => ref
                          .read(themeModeProvider.notifier)
                          .setDarkMode(value),
                    ),
                  ),
                ],
              ),
            ),
            enter(
              3,
              _GroupCard(
                title: 'Security & Legal',
                rows: [
                  _SettingRow(
                    icon: Icons.phonelink_lock_rounded,
                    color: AppColors.primary600,
                    title: 'Login method',
                    subtitle: profile.phone.trim().isEmpty
                        ? 'One-time code by SMS'
                        : 'One-time code by SMS to ${profile.phone.trim()}',
                    trailing: const DashboardToneBadge(
                      label: 'OTP',
                      color: AppColors.success,
                      icon: Icons.verified_user_rounded,
                    ),
                  ),
                  _SettingRow(
                    icon: Icons.privacy_tip_outlined,
                    color: AppColors.primary600,
                    title: 'Privacy Policy',
                    subtitle: 'How patient and practice data is protected',
                    onTap: () => _openLink(_LegalLinks.privacy),
                    trailing: const _OpenIcon(),
                  ),
                  _SettingRow(
                    icon: Icons.gavel_rounded,
                    color: AppColors.primary600,
                    title: 'Terms of Service',
                    subtitle: 'Your agreement with Doctylia',
                    onTap: () => _openLink(_LegalLinks.terms),
                    trailing: const _OpenIcon(),
                  ),
                  _SettingRow(
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.primary600,
                    title: 'Refund Policy',
                    subtitle: 'Subscriptions and patient payments',
                    onTap: () => _openLink(_LegalLinks.refunds),
                    trailing: const _OpenIcon(),
                  ),
                  _SettingRow(
                    icon: Icons.info_outline_rounded,
                    color: AppColors.mutedText(context),
                    title: 'App version',
                    subtitle: 'Installed build',
                    trailing: _ValuePill(version ?? '—'),
                  ),
                ],
              ),
            ),
            enter(
              4,
              _SessionCard(
                onLogout: () => DashboardShell.confirmLogout(context, ref),
                onDeleteAccount: () =>
                    DefaultTabController.maybeOf(context)?.animateTo(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    String key, {
    String? Function(String?)? validator,
    bool number = false,
    int lines = 1,
    bool profileStyle = false,
    bool obscureText = false,
    String? prefixText,
    String? suffixText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextFormField(
      controller: _c[key],
      validator: validator,
      maxLines: lines,
      obscureText: obscureText,
      enableSuggestions: !obscureText,
      autocorrect: !obscureText,
      keyboardType: number ? TextInputType.number : null,
      // Keeps the collapsed-row summaries current while typing.
      onChanged: (_) => setState(() {}),
      style: profileStyle
          ? const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)
          : null,
      decoration: _fieldDecoration(
        label,
        profileStyle: profileStyle,
        prefixText: prefixText,
        suffixText: suffixText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    ),
  );

  Widget _savedSuffix(IconData icon) => Tooltip(
    message: 'Saved on profile',
    child: Icon(icon, color: AppColors.success, size: 18),
  );

  static String _withoutDoctorPrefix(String value) => value
      .replaceFirst(RegExp(r'^\s*dr\.?\s*', caseSensitive: false), '')
      .trim();

  static String _withDoctorPrefix(String value) {
    final name = _withoutDoctorPrefix(value);
    return name.isEmpty ? '' : 'Dr. $name';
  }
}

// ── Executive profile header ─────────────────────────────────────────────

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.profile,
    required this.subscription,
    required this.onEdit,
    this.photoUrl,
    this.patients,
    this.rating,
  });

  final DoctorProfileSettings profile;
  final SubscriptionDetails subscription;
  final VoidCallback onEdit;
  final String? photoUrl;

  /// From the dashboard snapshot; null until it has loaded.
  final int? patients;

  /// Average rating; null when there are no reviews (or not loaded).
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final (status, healthy) = switch (subscription.status) {
      PlanStatus.trial => ('Trial practice', true),
      PlanStatus.active => ('Active practice', true),
      PlanStatus.expired => ('Plan expired', false),
      PlanStatus.cancelled => ('Plan cancelled', false),
    };
    final place = [
      profile.clinicName.trim(),
      profile.city.trim(),
    ].where((value) => value.isNotEmpty).join(' · ');
    final card = AppColors.isDark(context)
        ? AppColors.darkCard
        : AppColors.card;
    return DashboardSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primary600],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: card, width: 2),
                      boxShadow: DashboardTokens.shadow(context),
                    ),
                    child: photoUrl == null || photoUrl!.trim().isEmpty
                        ? _initialsText(profile.fullName)
                        : Image.network(
                            photoUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _initialsText(profile.fullName),
                          ),
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Tooltip(
                      message: status,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: healthy
                              ? AppColors.success
                              : AppColors.textLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: card, width: 2.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _doctorDisplayName(profile.fullName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.specialization.trim().isEmpty
                          ? 'Add your specialization'
                          : profile.specialization,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: DashboardTokens.tealDeep,
                      ),
                    ),
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.mutedText(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    DashboardToneBadge(
                      label: status,
                      color: healthy ? AppColors.success : AppColors.warning,
                      icon: healthy
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Edit profile',
                child: shadcn.IconButton.outline(
                  onPressed: onEdit,
                  density: shadcn.ButtonDensity.icon,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface(context).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
              border: Border.all(
                color: DashboardTokens.border(context).withValues(alpha: 0.6),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _StatCell(
                    value: profile.experienceYears > 0
                        ? '${profile.experienceYears}+ Yrs'
                        : '—',
                    label: 'Experience',
                  ),
                  const _CellDivider(),
                  _StatCell(
                    value: patients == null
                        ? '—'
                        : NumberFormat.compact(
                            locale: 'en_IN',
                          ).format(patients),
                    label: 'Patients',
                  ),
                  const _CellDivider(),
                  _StatCell(
                    value: rating == null
                        ? 'New'
                        : '★ ${rating!.toStringAsFixed(1)}',
                    label: 'Rating',
                    valueColor: rating == null ? null : const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _initialsText(String fullName) => Text(
    _initials(fullName),
    style: const TextStyle(
      color: Colors.white,
      fontSize: 21,
      fontWeight: FontWeight.w800,
    ),
  );

  static String _initials(String value) {
    final clean = value
        .replaceFirst(RegExp(r'^\s*dr\.?\s*', caseSensitive: false), '')
        .trim();
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'DR';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  static String _doctorDisplayName(String value) {
    final clean = value
        .replaceFirst(RegExp(r'^\s*dr\.?\s*', caseSensitive: false), '')
        .trim();
    return clean.isEmpty ? 'Doctor' : 'Dr. $clean';
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: valueColor ?? AppColors.onSurface(context),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.mutedText(context), fontSize: 11),
        ),
      ],
    ),
  );
}

class _CellDivider extends StatelessWidget {
  const _CellDivider();

  @override
  Widget build(BuildContext context) => VerticalDivider(
    width: 1,
    thickness: 1,
    color: DashboardTokens.border(context),
  );
}

// ── Grouped cards & rows ─────────────────────────────────────────────────

/// Section header + one bordered card whose rows are split by dividers.
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.rows,
    this.footer,
    super.key,
  });

  final String title;
  final List<Widget> rows;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
          child: Text(
            title.toUpperCase(),
            style: DashboardTokens.eyebrow(context).copyWith(fontSize: 11),
          ),
        ),
        DashboardSurface(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in rows.indexed) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 62,
                    color: DashboardTokens.border(context),
                  ),
                child,
              ],
              ?footer,
            ],
          ),
        ),
      ],
    ),
  );
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon, size: 19, color: color),
  );
}

class _RowText extends StatelessWidget {
  const _RowText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.onSurface(context),
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.mutedText(context), fontSize: 12),
      ),
    ],
  );
}

/// Plain settings row: icon · title/subtitle · trailing control.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            _IconBox(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: _RowText(title: title, subtitle: subtitle),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    ),
  );
}

/// A row that expands into an editor. The editor stays mounted while
/// collapsed (so the form still validates it) and the height animates.
class _ExpandableRow extends StatelessWidget {
  const _ExpandableRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    const duration = Duration(milliseconds: 260);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onToggle,
            child: Semantics(
              button: true,
              expanded: expanded,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    _IconBox(icon: icon, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RowText(title: title, subtitle: summary),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 6),
                      trailing!,
                    ],
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: reduce ? Duration.zero : duration,
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: expanded
                            ? AppColors.primary600
                            : AppColors.subtleText(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: reduce ? Duration.zero : duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Visibility(
            visible: expanded,
            maintainState: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _OpenIcon extends StatelessWidget {
  const _OpenIcon();

  @override
  Widget build(BuildContext context) => Icon(
    Icons.open_in_new_rounded,
    size: 17,
    color: AppColors.subtleText(context),
  );
}

class _ValuePill extends StatelessWidget {
  const _ValuePill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 150),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.secondarySurface(context),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.mutedText(context),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Log out (existing confirmation flow) + a pointer to account deletion.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.onLogout, required this.onDeleteAccount});

  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.destructive.withValues(alpha: 0.05),
          AppColors.isDark(context) ? AppColors.darkCard : AppColors.card,
        ),
        borderRadius: BorderRadius.circular(DashboardTokens.radius),
        border: Border.all(
          color: AppColors.destructive.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.destructive.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: AppColors.destructive,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Log Out',
                      style: TextStyle(
                        color: AppColors.destructive,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: onDeleteAccount,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mutedText(context),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Delete account…'),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Existing editor controls (unchanged) ─────────────────────────────────

class _MapPinButton extends StatelessWidget {
  const _MapPinButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 34),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
    ),
    icon: const Icon(Icons.open_in_new_rounded, size: 12),
    iconAlignment: IconAlignment.end,
    label: const Text('Map Pin'),
  );
}

class _GstInvoiceControl extends StatelessWidget {
  const _GstInvoiceControl({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
    decoration: BoxDecoration(
      color: AppColors.secondarySurface(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'GST Registered',
                      style: TextStyle(
                        color: AppColors.onSurface(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'TAX INVOICE',
                      style: TextStyle(
                        color: AppColors.primary600,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Show GST breakup & HSN codes on patient invoices',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.mutedText(context),
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.navy,
            activeThumbColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _TestModeBadge extends StatelessWidget {
  const _TestModeBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.55)),
    ),
    child: const Text(
      'TEST MODE',
      style: TextStyle(
        color: AppColors.warning,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.25,
      ),
    ),
  );
}

class _PayoutInfoBanner extends StatelessWidget {
  const _PayoutInfoBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.primary50.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
    ),
    child: Text.rich(
      const TextSpan(
        children: [
          TextSpan(
            text:
                'Used to pay out your share of online consultation payments directly with ',
          ),
          TextSpan(
            text: '0% platform commission.',
            style: TextStyle(
              color: AppColors.primary600,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11.5,
        height: 1.45,
      ),
    ),
  );
}

class _PayoutMethodSelector extends StatelessWidget {
  const _PayoutMethodSelector({required this.value, required this.onChanged});

  final PayoutMethod value;
  final ValueChanged<PayoutMethod> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _PayoutMethodChoice(
          label: 'Bank Account',
          icon: Icons.account_balance_rounded,
          selected: value == PayoutMethod.bank,
          onTap: () => onChanged(PayoutMethod.bank),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _PayoutMethodChoice(
          label: 'UPI ID',
          icon: Icons.smartphone_rounded,
          selected: value == PayoutMethod.upi,
          onTap: () => onChanged(PayoutMethod.upi),
        ),
      ),
    ],
  );
}

class _PayoutMethodChoice extends StatelessWidget {
  const _PayoutMethodChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? AppColors.primary.withValues(alpha: 0.055)
        : AppColors.secondarySurface(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border(context),
        width: selected ? 2 : 1,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : icon,
                size: 18,
                color: selected
                    ? AppColors.primary
                    : AppColors.subtleText(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: TextStyle(
                    color: selected
                        ? AppColors.onSurface(context)
                        : AppColors.mutedText(context),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                const Text(
                  'Active',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
