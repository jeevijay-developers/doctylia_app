import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/settings/domain/entities/settings_models.dart';
import 'package:doctylia_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseSettingsRepository implements SettingsRepository {
  SupabaseSettingsRepository(this._client);

  final SupabaseClient _client;

  String get _doctorId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<SettingsSnapshot>> load() => _guard(_load);

  Future<SettingsSnapshot> _load() async {
    final doctorId = _doctorId;
    final results = await Future.wait<dynamic>([
      _client.from('profiles').select().eq('id', doctorId).single(),
      _client
          .from('doctor_bank_accounts')
          .select()
          .eq('doctor_id', doctorId)
          .maybeSingle(),
      _client
          .from('pending_plans')
          .select(
            'id,target_tier,activation_date,payment_id,created_at,plan_upgrade_payments(amount,status)',
          )
          .eq('doctor_id', doctorId)
          .maybeSingle(),
      _client.from('platform_settings').select('key,value').inFilter('key', [
        'pro_default_price',
        'premium_default_price',
      ]),
      _client.rpc(
        'get_appointment_cap_usage',
        params: {'_doctor_id': doctorId},
      ),
      _client.functions.invoke('get-payment-mode'),
    ]);
    final profile = Map<String, dynamic>.from(results[0] as Map);
    final bank = results[1] is Map
        ? Map<String, dynamic>.from(results[1] as Map)
        : null;
    final pending = results[2] is Map
        ? Map<String, dynamic>.from(results[2] as Map)
        : null;
    final prices = (results[3] as List).cast<Map<String, dynamic>>();
    final usageRows = results[4] as List;
    final modeData = _responseMap((results[5] as FunctionResponse).data);
    final mode = switch (modeData['mode']) {
      'mock' => PaymentMode.mock,
      'live' => PaymentMode.live,
      _ => throw const RemoteServiceFailure(
        'Could not determine payment mode. Please retry before making a payment.',
      ),
    };
    final defaults = <String, double>{'pro': 1499, 'premium': 3999};
    for (final row in prices) {
      final value = _number(row['value']);
      final key = switch (row['key']) {
        'pro_default_price' => 'pro',
        'premium_default_price' => 'premium',
        _ => null,
      };
      if (value != null && key != null) {
        defaults[key] = value;
      }
    }
    final currentTier = profile['plan_tier'] as String? ?? 'free';
    final customPrice = _number(profile['custom_plan_price']);
    final usage = usageRows.isNotEmpty && usageRows.first is Map
        ? Map<String, dynamic>.from(usageRows.first as Map)
        : const <String, dynamic>{};
    return SettingsSnapshot(
      profile: _profile(profile),
      payoutAccount: bank == null ? null : _payout(bank),
      paymentMode: mode,
      subscription: SubscriptionDetails(
        tier: _tier(currentTier),
        status: _status(profile['plan_status'] as String),
        proPrice: _tierPrice('pro', currentTier, customPrice, defaults['pro']!),
        premiumPrice: _tierPrice(
          'premium',
          currentTier,
          customPrice,
          defaults['premium']!,
        ),
        appointmentsUsed: (usage['appointments_used'] as num?)?.toInt() ?? 0,
        appointmentsCap: (usage['appointments_cap'] as num?)?.toInt() ?? 0,
        trialEnd: _date(profile['trial_end']),
        planEnd: _date(profile['plan_end']),
        pendingPlan: pending == null ? null : _pending(pending),
      ),
    );
  }

  @override
  Future<Result<DoctorProfileSettings>> saveProfile(
    DoctorProfileSettings profile,
  ) => _guard(() async {
    _validateProfile(profile);
    final doctorId = _doctorId;
    final current = await _client
        .from('profiles')
        .select('full_name,slug')
        .eq('id', doctorId)
        .single();
    final phone = _normalizePhone(profile.phone);
    final values = <String, dynamic>{
      'full_name': profile.fullName.trim(),
      'specialization': profile.specialization.trim(),
      'qualifications': _empty(profile.qualifications),
      'experience_years': profile.experienceYears,
      'phone': _empty(phone),
      'clinic_name': _empty(profile.clinicName),
      'city': _empty(profile.city),
      'state': _empty(profile.state),
      'address': _empty(profile.address),
      'consultation_fee': profile.consultationFee,
      'registration_number': _empty(profile.registrationNumber),
      'clinic_email': _empty(profile.clinicEmail),
      'gst_registered': profile.gstRegistered,
      'gstin': profile.gstRegistered
          ? _empty(profile.gstin.toUpperCase())
          : null,
    };
    String? oldSlug;
    final oldName = current['full_name'] as String?;
    if (profile.fullName.trim() != (oldName ?? '').trim()) {
      var slug = _slug(profile.fullName);
      if (slug.isNotEmpty && slug != current['slug']) {
        final clash = await _client
            .from('profiles')
            .select('id')
            .eq('slug', slug)
            .neq('id', doctorId)
            .maybeSingle();
        if (clash != null) {
          slug = '$slug-${DateTime.now().millisecondsSinceEpoch % 10000}';
        }
        values['slug'] = slug;
        oldSlug = current['slug'] as String?;
      }
    }
    await _client.from('profiles').update(values).eq('id', doctorId);
    if (oldSlug != null && oldSlug.isNotEmpty && values['slug'] != null) {
      await _client.from('slug_history').insert({
        'doctor_id': doctorId,
        'old_slug': oldSlug,
      });
    }
    return DoctorProfileSettings(
      fullName: profile.fullName.trim(),
      specialization: profile.specialization.trim(),
      qualifications: profile.qualifications.trim(),
      experienceYears: profile.experienceYears,
      phone: phone,
      clinicName: profile.clinicName.trim(),
      city: profile.city.trim(),
      state: profile.state.trim(),
      address: profile.address.trim(),
      consultationFee: profile.consultationFee,
      registrationNumber: profile.registrationNumber.trim(),
      clinicEmail: profile.clinicEmail.trim(),
      gstRegistered: profile.gstRegistered,
      gstin: profile.gstRegistered ? profile.gstin.trim().toUpperCase() : '',
    );
  });

  @override
  Future<Result<DoctorPayoutAccount>> savePayoutAccount(
    DoctorPayoutAccount account,
  ) => _guard(() async {
    final body = account.method == PayoutMethod.bank
        ? {
            if (account.accountHolderName.trim().isNotEmpty)
              'account_holder_name': account.accountHolderName.trim(),
            'account_number': account.accountNumber?.trim(),
            'ifsc': account.ifsc?.trim().toUpperCase(),
          }
        : {
            if (account.accountHolderName.trim().isNotEmpty)
              'account_holder_name': account.accountHolderName.trim(),
            'upi_id': account.upiId?.trim(),
          };
    final response = await _client.functions
        .invoke('add-doctor-bank-account', body: body)
        .timeout(const Duration(seconds: 30));
    final data = _responseMap(response.data);
    if (data['ok'] != true) {
      throw const RemoteServiceFailure(
        'Could not save payout details. Please try again.',
      );
    }
    final row = await _client
        .from('doctor_bank_accounts')
        .select()
        .eq('doctor_id', _doctorId)
        .single();
    return _payout(row);
  });

  @override
  Future<Result<CheckoutOrder>> createCheckoutOrder(PlanTier targetTier) =>
      _guard(() async {
        if (targetTier == PlanTier.free) {
          throw const ValidationFailure('Choose Pro or Premium.');
        }
        final response = await _client.functions
            .invoke(
              'create-plan-upgrade-order',
              body: {'target_tier': targetTier.name},
            )
            .timeout(const Duration(seconds: 30));
        final data = _responseMap(response.data);
        final mode = data['mode'];
        if (data['order_id'] is! String ||
            data['payment_id'] is! String ||
            data['key_id'] is! String ||
            data['amount'] is! num ||
            (mode != 'mock' && mode != 'live')) {
          throw const RemoteServiceFailure(
            'Checkout returned an invalid order. Please try again.',
          );
        }
        return CheckoutOrder(
          orderId: data['order_id'] as String,
          keyId: data['key_id'] as String,
          paymentId: data['payment_id'] as String,
          targetTier: targetTier,
          amountPaise: (data['amount'] as num).toInt(),
          currency: data['currency'] as String? ?? 'INR',
          isMock: mode == 'mock',
        );
      });

  @override
  Future<Result<CheckoutVerification>> simulateMockCheckout(
    CheckoutOrder order,
  ) => _guard(() async {
    if (!order.isMock) {
      throw const ValidationFailure('This is not a test-mode payment.');
    }
    final response = await _client.functions
        .invoke(
          'mock-simulate-payment',
          body: {'payment_id': order.paymentId, 'result': 'success'},
        )
        .timeout(const Duration(seconds: 30));
    final data = _responseMap(response.data);
    return _verification(data);
  });

  @override
  Future<Result<SubscriptionDetails>> verifyCheckout(
    CheckoutOrder order,
    CheckoutVerification verification,
  ) => _guard(() async {
    final response = await _client.functions
        .invoke(
          'verify-plan-upgrade-payment',
          body: {
            'payment_id': order.paymentId,
            'razorpay_order_id': verification.razorpayOrderId,
            'razorpay_payment_id': verification.razorpayPaymentId,
            'razorpay_signature': verification.razorpaySignature,
          },
        )
        .timeout(const Duration(seconds: 30));
    if (_responseMap(response.data)['ok'] != true) {
      throw const RemoteServiceFailure(
        'Payment verification failed. Contact support with your payment ID.',
      );
    }
    return (await _load()).subscription;
  });

  @override
  Future<Result<SubscriptionDetails>> cancelScheduledPlan(
    String pendingPlanId,
  ) => _guard(() async {
    final response = await _client.functions
        .invoke(
          'cancel-scheduled-plan',
          body: {'pending_plan_id': pendingPlanId},
        )
        .timeout(const Duration(seconds: 30));
    if (_responseMap(response.data)['ok'] != true) {
      throw const RemoteServiceFailure(
        'Could not cancel the scheduled plan. Please try again.',
      );
    }
    return (await _load()).subscription;
  });

  static DoctorProfileSettings _profile(Map<String, dynamic> row) =>
      DoctorProfileSettings(
        fullName: row['full_name'] as String? ?? '',
        specialization: row['specialization'] as String? ?? '',
        qualifications: row['qualifications'] as String? ?? '',
        experienceYears: (row['experience_years'] as num?)?.toInt() ?? 0,
        phone: row['phone'] as String? ?? '',
        clinicName: row['clinic_name'] as String? ?? '',
        city: row['city'] as String? ?? '',
        state: row['state'] as String? ?? '',
        address: row['address'] as String? ?? '',
        consultationFee: (row['consultation_fee'] as num).toDouble(),
        registrationNumber: row['registration_number'] as String? ?? '',
        clinicEmail: row['clinic_email'] as String? ?? '',
        gstRegistered: row['gst_registered'] as bool,
        gstin: row['gstin'] as String? ?? '',
      );

  static DoctorPayoutAccount _payout(Map<String, dynamic> row) =>
      DoctorPayoutAccount(
        method: (row['upi_id'] as String?)?.isNotEmpty == true
            ? PayoutMethod.upi
            : PayoutMethod.bank,
        accountHolderName: row['account_holder_name'] as String? ?? '',
        accountNumber: row['account_number'] as String?,
        ifsc: row['ifsc'] as String?,
        upiId: row['upi_id'] as String?,
        verified: row['verified'] as bool,
        isMock: row['is_mock'] as bool,
      );

  static PendingPlan _pending(Map<String, dynamic> row) {
    final relation = row['plan_upgrade_payments'];
    final payment = relation is Map
        ? Map<String, dynamic>.from(relation)
        : relation is List && relation.isNotEmpty && relation.first is Map
        ? Map<String, dynamic>.from(relation.first as Map)
        : const <String, dynamic>{};
    return PendingPlan(
      id: row['id'] as String,
      targetTier: _tier(row['target_tier'] as String),
      activationDate: DateTime.parse(row['activation_date'] as String),
      amount: (payment['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  static CheckoutVerification _verification(Map<String, dynamic> data) {
    if (data['razorpay_order_id'] is! String ||
        data['razorpay_payment_id'] is! String ||
        data['razorpay_signature'] is! String) {
      throw const RemoteServiceFailure(
        'The payment gateway returned an invalid result. Please try again.',
      );
    }
    return CheckoutVerification(
      razorpayOrderId: data['razorpay_order_id'] as String,
      razorpayPaymentId: data['razorpay_payment_id'] as String,
      razorpaySignature: data['razorpay_signature'] as String,
    );
  }

  static void _validateProfile(DoctorProfileSettings profile) {
    if (profile.fullName.trim().isEmpty) {
      throw const ValidationFailure('Full name is required.');
    }
    if (profile.specialization.trim().isEmpty) {
      throw const ValidationFailure('Specialization is required.');
    }
    if (profile.experienceYears < 0) {
      throw const ValidationFailure('Years of experience cannot be negative.');
    }
    if (profile.consultationFee < 0) {
      throw const ValidationFailure('Consultation fee cannot be negative.');
    }
    final phone = _normalizePhone(profile.phone);
    if (phone.isNotEmpty && !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      throw const ValidationFailure(
        'Enter a valid 10-digit Indian mobile number.',
      );
    }
  }

  static String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    return digits;
  }

  static String _slug(String value) => value
      .toLowerCase()
      .trim()
      .replaceFirst(RegExp(r'^dr\.?\s*'), 'dr-')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static double _tierPrice(
    String tier,
    String currentTier,
    double? customPrice,
    double defaultPrice,
  ) {
    if (customPrice != null &&
        (currentTier == tier ||
            ((currentTier == 'free' || currentTier == 'trial') &&
                tier == 'pro'))) {
      return customPrice;
    }
    return defaultPrice;
  }

  static PlanTier _tier(String value) => switch (value) {
    'premium' => PlanTier.premium,
    'pro' => PlanTier.pro,
    'free' || 'trial' => PlanTier.free,
    _ => throw FormatException('Unknown plan tier: $value'),
  };

  static PlanStatus _status(String value) => switch (value) {
    'trial' => PlanStatus.trial,
    'active' => PlanStatus.active,
    'expired' => PlanStatus.expired,
    'cancelled' => PlanStatus.cancelled,
    _ => throw FormatException('Unknown plan status: $value'),
  };

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
  static double? _number(Object? value) => switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };
  static String? _empty(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic> _responseMap(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  Future<Result<T>> _guard<T>(Future<T> Function() operation) =>
      RepositoryGuard.run(() async {
        try {
          return await operation();
        } catch (error, stackTrace) {
          if (error is AppFailure) rethrow;
          if (error is FunctionException) {
            final details = error.details;
            final detailMap = details is Map
                ? Map<String, dynamic>.from(details)
                : const <String, dynamic>{};
            final detail = detailMap['error'] ?? detailMap['message'];
            final message = detail is String && detail.isNotEmpty
                ? detail
                : 'The requested action failed. Please try again.';
            if (error.status == 401) throw const SessionExpiredFailure();
            if (error.status == 403) throw const PermissionFailure();
            if (error.status == 409) {
              throw ConflictFailure(message, cause: error);
            }
            if (error.status == 429) throw const RateLimitFailure();
            throw RemoteServiceFailure(
              message,
              cause: error,
              stackTrace: stackTrace,
            );
          }
          final message = error.toString().toLowerCase();
          if (error is TimeoutException ||
              message.contains('socketexception') ||
              message.contains('failed host lookup')) {
            throw NetworkFailure(cause: error, stackTrace: stackTrace);
          }
          if (error is PostgrestException) {
            if (error.code == '42501') throw const PermissionFailure();
            if (error.code == '23505') {
              throw ConflictFailure(
                'That value is already in use.',
                cause: error,
              );
            }
          }
          throw ServerFailure(cause: error, stackTrace: stackTrace);
        }
      });
}
