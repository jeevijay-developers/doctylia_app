import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/auth/presentation/screens/account_rejection_screen.dart';
import 'package:doctylia_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:doctylia_app/features/auth/presentation/screens/login_screen.dart';
import 'package:doctylia_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:doctylia_app/features/auth/presentation/screens/subscription_blocked_screen.dart';
import 'package:doctylia_app/features/auth/presentation/state/auth_state.dart';
import 'package:doctylia_app/features/appointments/presentation/screens/appointments_screen.dart';
import 'package:doctylia_app/features/billing/presentation/screens/billing_screen.dart';
import 'package:doctylia_app/features/blog/presentation/screens/blog_screen.dart';
import 'package:doctylia_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:doctylia_app/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:doctylia_app/features/dashboard/presentation/screens/more_screen.dart';
import 'package:doctylia_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:doctylia_app/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:doctylia_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:doctylia_app/features/inquiries/presentation/screens/inquiries_screen.dart';
import 'package:doctylia_app/features/patients/presentation/screens/patient_medical_record_screen.dart';
import 'package:doctylia_app/features/patients/presentation/screens/patients_screen.dart';
import 'package:doctylia_app/features/prescriptions/presentation/screens/prescriptions_screen.dart';
import 'package:doctylia_app/features/reviews/presentation/screens/reviews_screen.dart';
import 'package:doctylia_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:doctylia_app/features/staff/presentation/screens/staff_management_screen.dart';
import 'package:doctylia_app/features/support/presentation/screens/support_screen.dart';
import 'package:doctylia_app/features/website/presentation/screens/my_website_screen.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  late final GoRouter router;
  router = GoRouter(
    initialLocation: RoutePaths.splash,
    redirect: (context, state) {
      final authAsync = ref.read(authControllerProvider);
      final onboardingAsync = ref.read(onboardingSeenProvider);
      final location = state.matchedLocation;

      if (authAsync.isLoading || onboardingAsync.isLoading) {
        return location == RoutePaths.splash ? null : RoutePaths.splash;
      }

      final auth =
          authAsync.value ??
          const AuthState.accountError('Unable to restore your session.');

      switch (auth.status) {
        case AuthStatus.authenticatedDoctor:
          final session = auth.session!;
          final access = TrialAccessResolver.resolve(
            status: session.planStatus,
            trialEnd: session.trialEnd,
            now: DateTime.now(),
          );
          if (access == TrialAccessLevel.blocked) {
            return location == RoutePaths.accessBlocked
                ? null
                : RoutePaths.accessBlocked;
          }
          final isAppRoute =
              location == RoutePaths.app ||
              location.startsWith('${RoutePaths.app}/');
          return isAppRoute ? null : RoutePaths.dashboard;
        case AuthStatus.staffRejected:
          return location == RoutePaths.staffRejected
              ? null
              : RoutePaths.staffRejected;
        case AuthStatus.accountError:
          return location == RoutePaths.accountError
              ? null
              : RoutePaths.accountError;
        case AuthStatus.unauthenticated:
          final hasSeenOnboarding = onboardingAsync.value ?? false;
          if (!hasSeenOnboarding) {
            return location == RoutePaths.onboarding
                ? null
                : RoutePaths.onboarding;
          }
          final isPublicAuthRoute =
              location == RoutePaths.login ||
              location == RoutePaths.forgotPassword;
          return isPublicAuthRoute ? null : RoutePaths.login;
      }
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        name: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.staffRejected,
        name: RouteNames.staffRejected,
        builder: (context, state) {
          return const AccountRejectionScreen(isStaffAccount: true);
        },
      ),
      GoRoute(
        path: RoutePaths.accountError,
        name: RouteNames.accountError,
        builder: (context, state) {
          final message = ref.read(authControllerProvider).value?.errorMessage;
          return AccountRejectionScreen(
            isStaffAccount: false,
            message: message,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.accessBlocked,
        name: RouteNames.accessBlocked,
        builder: (context, state) {
          final session = ref.read(authControllerProvider).value?.session;
          if (session == null) return const SplashScreen();
          return SubscriptionBlockedScreen(session: session);
        },
      ),
      GoRoute(
        path: RoutePaths.app,
        redirect: (context, state) => RoutePaths.dashboard,
      ),
      GoRoute(
        path: RoutePaths.notifications,
        name: RouteNames.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            name: RouteNames.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: RoutePaths.appointments,
            name: RouteNames.appointments,
            builder: (context, state) => const AppointmentsScreen(),
          ),
          GoRoute(
            path: RoutePaths.patients,
            name: RouteNames.patients,
            builder: (context, state) => const PatientsScreen(),
          ),
          GoRoute(
            path: '${RoutePaths.patients}/:patientId',
            name: RouteNames.patientRecord,
            builder: (context, state) => PatientMedicalRecordScreen(
              patientId: state.pathParameters['patientId']!,
            ),
          ),
          GoRoute(
            path: RoutePaths.more,
            name: RouteNames.more,
            builder: (context, state) => const MoreScreen(),
          ),
          GoRoute(
            path: RoutePaths.prescriptions,
            name: RouteNames.prescriptions,
            builder: (context, state) => const PrescriptionsScreen(),
          ),
          GoRoute(
            path: RoutePaths.billing,
            name: RouteNames.billing,
            builder: (context, state) => const BillingScreen(),
          ),
          GoRoute(
            path: RoutePaths.settings,
            name: RouteNames.settings,
            builder: (context, state) => SettingsScreen(
              initialTab: state.uri.queryParameters['tab'] ?? 'profile',
            ),
          ),
          GoRoute(
            path: RoutePaths.myWebsite,
            name: RouteNames.myWebsite,
            builder: (context, state) => const MyWebsiteScreen(),
          ),
          GoRoute(
            path: RoutePaths.blog,
            name: RouteNames.blog,
            builder: (context, state) => const BlogScreen(),
          ),
          GoRoute(
            path: RoutePaths.reviews,
            name: RouteNames.reviews,
            builder: (context, state) => const ReviewsScreen(),
          ),
          GoRoute(
            path: RoutePaths.inquiries,
            name: RouteNames.inquiries,
            builder: (context, state) => const InquiriesScreen(),
          ),
          GoRoute(
            path: RoutePaths.staff,
            name: RouteNames.staff,
            builder: (context, state) => const StaffManagementScreen(),
          ),
          GoRoute(
            path: RoutePaths.support,
            name: RouteNames.support,
            builder: (context, state) => const SupportScreen(),
          ),
        ],
      ),
    ],
  );

  ref.listen(authControllerProvider, (_, _) => router.refresh());
  ref.listen(onboardingSeenProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
