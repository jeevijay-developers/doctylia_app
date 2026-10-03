import 'dart:async';

import 'package:doctylia_app/app/app.dart';
import 'package:doctylia_app/app/app_flavor.dart';
import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/config/supabase_config.dart';
import 'package:doctylia_app/core/logging/app_logger.dart';
import 'package:doctylia_app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/appointments/data/repositories/supabase_appointment_repository.dart';
import 'package:doctylia_app/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:doctylia_app/features/blog/data/repositories/supabase_blog_repository.dart';
import 'package:doctylia_app/features/blog/presentation/providers/blog_providers.dart';
import 'package:doctylia_app/features/billing/data/repositories/supabase_billing_repository.dart';
import 'package:doctylia_app/features/billing/presentation/providers/billing_providers.dart';
import 'package:doctylia_app/features/dashboard/data/repositories/supabase_dashboard_repository.dart';
import 'package:doctylia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:doctylia_app/features/inquiries/data/repositories/supabase_inquiry_repository.dart';
import 'package:doctylia_app/features/inquiries/presentation/providers/inquiry_providers.dart';
import 'package:doctylia_app/features/patients/data/repositories/supabase_patient_repository.dart';
import 'package:doctylia_app/features/patients/presentation/providers/patient_providers.dart';
import 'package:doctylia_app/features/prescriptions/data/repositories/supabase_prescription_repository.dart';
import 'package:doctylia_app/features/prescriptions/presentation/providers/prescription_providers.dart';
import 'package:doctylia_app/features/reviews/data/repositories/supabase_review_repository.dart';
import 'package:doctylia_app/features/reviews/presentation/providers/review_providers.dart';
import 'package:doctylia_app/features/settings/data/repositories/supabase_settings_repository.dart';
import 'package:doctylia_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:doctylia_app/features/staff/data/repositories/supabase_staff_repository.dart';
import 'package:doctylia_app/features/staff/presentation/providers/staff_providers.dart';
import 'package:doctylia_app/features/support/data/repositories/supabase_support_repository.dart';
import 'package:doctylia_app/features/support/presentation/providers/support_providers.dart';
import 'package:doctylia_app/features/website/data/repositories/supabase_website_repository.dart';
import 'package:doctylia_app/features/website/presentation/providers/website_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> bootstrap({AppFlavor flavor = AppFlavor.mock}) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppLogger.error(
          'Uncaught Flutter error',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      await dotenv.load(fileName: '.env');
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );

      runApp(
        ProviderScope(
          // Riverpod 3 silently retries failing providers for up to ~40s and
          // reports AsyncLoading meanwhile, so screens showed an endless
          // spinner instead of the error view. Every screen already offers
          // an explicit Retry, so surface failures immediately.
          retry: (_, _) => null,
          overrides: [
            appDataSourceProvider.overrideWithValue(appDataSourceFor(flavor)),
            authRepositoryProvider.overrideWithValue(
              SupabaseAuthRepository(Supabase.instance.client),
            ),
            dashboardRepositoryProvider.overrideWithValue(
              SupabaseDashboardRepository(Supabase.instance.client),
            ),
            inquiryRepositoryProvider.overrideWithValue(
              SupabaseInquiryRepository(Supabase.instance.client),
            ),
            appointmentRepositoryProvider.overrideWithValue(
              SupabaseAppointmentRepository(Supabase.instance.client),
            ),
            blogRepositoryProvider.overrideWithValue(
              SupabaseBlogRepository(Supabase.instance.client),
            ),
            billingRepositoryProvider.overrideWithValue(
              SupabaseBillingRepository(Supabase.instance.client),
            ),
            patientRepositoryProvider.overrideWithValue(
              SupabasePatientRepository(Supabase.instance.client),
            ),
            prescriptionRepositoryProvider.overrideWithValue(
              SupabasePrescriptionRepository(Supabase.instance.client),
            ),
            reviewRepositoryProvider.overrideWithValue(
              SupabaseReviewRepository(Supabase.instance.client),
            ),
            settingsRepositoryProvider.overrideWithValue(
              SupabaseSettingsRepository(Supabase.instance.client),
            ),
            staffRepositoryProvider.overrideWithValue(
              SupabaseStaffRepository(Supabase.instance.client),
            ),
            supportRepositoryProvider.overrideWithValue(
              SupabaseSupportRepository(Supabase.instance.client),
            ),
            websiteRepositoryProvider.overrideWithValue(
              SupabaseWebsiteRepository(Supabase.instance.client),
            ),
          ],
          child: const DoctyliaApp(),
        ),
      );
    },
    (error, stackTrace) => AppLogger.error(
      'Uncaught asynchronous error',
      error: error,
      stackTrace: stackTrace,
    ),
  );
}
