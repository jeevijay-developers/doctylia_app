import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/settings/domain/entities/settings_models.dart';
import 'package:doctylia_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class ProfileSettingsTab extends ConsumerStatefulWidget {
  const ProfileSettingsTab({required this.snapshot, super.key});
  final SettingsSnapshot snapshot;
  @override
  ConsumerState<ProfileSettingsTab> createState() => _ProfileSettingsTabState();
}

class _ProfileSettingsTabState extends ConsumerState<ProfileSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late bool _gst;
  late PayoutMethod _method;
  bool _saving = false;
  bool _savingPayout = false;

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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
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

  @override
  Widget build(BuildContext context) {
    final appProfile = ref.watch(doctorProfileProvider);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _ProfileOverviewCard(
            profile: widget.snapshot.profile,
            subscription: widget.snapshot.subscription,
            photoUrl: appProfile?.profilePhotoUrl,
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Your Details',
            subtitle: 'Doctor credentials & charges',
            icon: Icons.person_outline_rounded,
            featured: true,
            trailing: const _EditableBadge(),
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
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textLight,
                  size: 19,
                ),
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
                suffixIcon: _savedSuffix(Icons.verified_user_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Clinic Details',
            subtitle: 'Physical address & patient invoice info',
            icon: Icons.location_on_outlined,
            featured: true,
            trailing: _MapPinButton(onPressed: _openClinicMap),
            children: [
              _field(
                'Clinic Name',
                'clinic',
                profileStyle: true,
                suffixIcon: _savedSuffix(Icons.check_circle_outline_rounded),
              ),
              Row(
                children: [
                  Expanded(child: _field('City', 'city', profileStyle: true)),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: _field('State', 'state', profileStyle: true)),
                ],
              ),
              _field('Full Address', 'address', lines: 2, profileStyle: true),
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
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Bank / UPI Setup',
            subtitle: 'Automatic daily payouts for practice',
            icon: Icons.account_balance_outlined,
            featured: true,
            trailing: widget.snapshot.paymentMode == PaymentMode.mock
                ? const _TestModeBadge()
                : null,
            children: [
              const _PayoutInfoBanner(),
              const SizedBox(height: 14),
              _PayoutMethodSelector(
                value: _method,
                onChanged: (value) => setState(() => _method = value),
              ),
              const SizedBox(height: 16),
              _field('Account Holder Name', 'holder', profileStyle: true),
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
                  suffixIcon: widget.snapshot.payoutAccount?.verified == true
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
                  suffixIcon: widget.snapshot.payoutAccount?.verified == true
                      ? const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: AppColors.success,
                        )
                      : null,
                ),
              const SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _savingPayout ? null : _savePayout,
                  icon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _savingPayout ? 'Saving...' : 'Save Payout Details',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onPressed: _saving ? null : _saveProfile,
              icon: const Icon(Icons.save_rounded),
              label: Text(
                _saving ? 'Saving...' : 'Save Profile & Clinic Settings',
              ),
            ),
          ),
        ],
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

class _ProfileOverviewCard extends StatelessWidget {
  const _ProfileOverviewCard({
    required this.profile,
    required this.subscription,
    this.photoUrl,
  });

  final DoctorProfileSettings profile;
  final SubscriptionDetails subscription;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final status = switch (subscription.status) {
      PlanStatus.trial => 'Trial practice',
      PlanStatus.active => 'Active practice',
      PlanStatus.expired => 'Plan expired',
      PlanStatus.cancelled => 'Plan cancelled',
    };
    final healthy =
        subscription.status == PlanStatus.active ||
        subscription.status == PlanStatus.trial;
    final experience = profile.experienceYears > 0
        ? ' · ${profile.experienceYears} Yrs Exp.'
        : '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context),
            blurRadius: 13,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primary600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: photoUrl == null || photoUrl!.trim().isEmpty
                    ? Text(
                        _initials(profile.fullName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Image.network(
                        photoUrl!,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Text(
                          _initials(profile.fullName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: healthy ? AppColors.success : AppColors.textLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).cardColor,
                      width: 2,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${profile.specialization}$experience',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText(context),
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _ProfileBadge(
                      icon: healthy
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                      label: status,
                      color: healthy ? AppColors.success : AppColors.warning,
                    ),
                    _ProfileBadge(
                      label:
                          '₹${profile.consultationFee.toStringAsFixed(0)} / Visit',
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: photoUrl == null ? 'No profile photo' : 'Profile photo',
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.secondarySurface(context),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: 17,
                color: AppColors.mutedText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _EditableBadge extends StatelessWidget {
  const _EditableBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.primary50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.primary200),
    ),
    child: const Text(
      'Editable',
      style: TextStyle(
        color: AppColors.primary600,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

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

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.featured = false,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  final bool featured;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(featured ? 18 : AppRadius.md),
      border: Border.all(color: AppColors.border(context)),
      boxShadow: featured
          ? [
              BoxShadow(
                color: AppColors.shadow(context, alpha: 0.045),
                blurRadius: 13,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: featured ? 14 : null,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: AppColors.subtleText(context),
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    ),
  );
}
