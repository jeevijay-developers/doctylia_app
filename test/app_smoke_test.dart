import 'package:doctylia_app/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:doctylia_app/app/app.dart';
import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:doctylia_app/core/platform/file_download_service.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:doctylia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_preferences_store.dart';
import 'support/counting_dashboard_repository.dart';

void main() {
  testWidgets('onboards, rejects bad login, authenticates, and logs out', (
    tester,
  ) async {
    final preferences = FakePreferencesStore();
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    expect(find.text('Manage Smart. Heal More.'), findsOneWidget);
    await tester.tap(find.text('Let’s Simplify'));
    await tester.pumpAndSettle();
    expect(find.text('Book Smart.\nNever Miss.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Organized Files.\nZero Chaos.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Track Growth.\nGrow Smart.'), findsOneWidget);
    await tester.tap(find.text('Join Doctylia'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, Doctor'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'doctor@gmail.com');
    await tester.enterText(fields.at(1), 'wrong');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect email or password.'), findsOneWidget);

    await tester.enterText(fields.at(1), 'doctor123');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('TOTAL PRACTICE REVENUE'), findsOneWidget);
    expect(find.text('124'), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, Doctor'), findsOneWidget);
  });

  testWidgets('restores a persisted doctor directly to the protected route', (
    tester,
  ) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    expect(find.text('Appointments'), findsWidgets);
    expect(find.text('TOTAL PRACTICE REVENUE'), findsOneWidget);
  });

  testWidgets('opens notifications as an individual screen', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Your notifications'), findsOneWidget);
    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile icon opens profile and logout drawer', (tester) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    bool showsLogo(String assetName) => tester
        .widgetList<Image>(find.byType(Image))
        .where((image) => image.image is AssetImage)
        .map((image) => (image.image as AssetImage).assetName)
        .contains(assetName);
    expect(showsLogo('assets/logo/doctylia-logo.png'), isTrue);

    await tester.tap(find.byTooltip('Profile menu'));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(preferences.values['theme_mode'], 'dark');
    expect(showsLogo('assets/logo/doctylia-logo-dark.png'), isTrue);
    expect(showsLogo('assets/logo/doctylia-logo.png'), isFalse);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Your Details'), findsOneWidget);
    final doctorName = tester
        .widgetList<Text>(find.text('Dr. Doctor'))
        .firstWhere((text) => text.style?.color != null);
    expect(doctorName.style?.color, AppColors.darkForeground);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows mock password reset confirmation', (tester) async {
    final preferences = FakePreferencesStore({'has_seen_onboarding': true});
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'doctor@gmail.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(
      find.textContaining('a password reset link is on its way'),
      findsOneWidget,
    );
  });

  testWidgets('creates an appointment from the center navigation action', (
    tester,
  ) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(
      find.descendant(of: bar, matching: find.byIcon(Icons.add_rounded)),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test Patient');
    await tester.enterText(fields.at(1), '9876543210');
    await tester.ensureVisible(find.text('Add appointment'));
    await tester.tap(find.text('Add appointment'));
    await tester.pumpAndSettle();

    expect(find.text('Appointment added'), findsOneWidget);
  });

  testWidgets('keeps dashboard cached across tab switches', (tester) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    final repository = CountingDashboardRepository();
    await tester.pumpWidget(
      _testApp(preferences, dashboardRepository: repository),
    );
    await tester.pumpAndSettle();
    expect(repository.loadCount, 1);

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(
      find.descendant(of: bar, matching: find.text('Appointments')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: bar, matching: find.text('Home')));
    await tester.pumpAndSettle();

    expect(find.text('Appointments'), findsWidgets);
    expect(repository.loadCount, 1);
  });

  testWidgets('uses the navigation rail on tablet-width layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });

    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(DashboardShell.bottomNavKey), findsNothing);
    expect(find.text('TOTAL PRACTICE REVENUE'), findsOneWidget);
  });

  testWidgets('renders the redesigned More screen on a narrow phone', (
    tester,
  ) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    await tester.pumpAndSettle();

    expect(find.text('ALL MODULES & SERVICES'), findsOneWidget);
    expect(find.text('9 practice tools connected & active'), findsOneWidget);
    expect(find.text('Sync active'), findsOneWidget);
    expect(find.text('Prescriptions'), findsOneWidget);
    expect(find.text('Manage digital Rx templates & history'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
  });

  testWidgets('system back from a More module returns to More', (tester) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(find.descendant(of: bar, matching: find.text('More')));
    await tester.pumpAndSettle();
    expect(find.text('ALL MODULES & SERVICES'), findsOneWidget);

    await tester.tap(find.text('My Website'));
    await tester.pumpAndSettle();
    expect(find.text('Your public website'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('ALL MODULES & SERVICES'), findsOneWidget);
    expect(find.text('My Website'), findsOneWidget);
  });

  testWidgets('system back from More returns to Home', (tester) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(find.descendant(of: bar, matching: find.text('More')));
    await tester.pumpAndSettle();
    expect(find.text('ALL MODULES & SERVICES'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('TOTAL PRACTICE REVENUE'), findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.text('Home')),
      findsOneWidget,
    );
  });

  testWidgets('system back from Appointments and Patients returns to Home', (
    tester,
  ) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    var bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(
      find.descendant(of: bar, matching: find.text('Appointments')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search patient or service'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('TOTAL PRACTICE REVENUE'), findsOneWidget);

    bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(find.descendant(of: bar, matching: find.text('Patients')));
    await tester.pumpAndSettle();
    expect(find.text('Search name or phone'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('TOTAL PRACTICE REVENUE'), findsOneWidget);
  });

  testWidgets('Backspace from Appointments returns to Home', (tester) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(
      find.descendant(of: bar, matching: find.text('Appointments')),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(find.text('TOTAL PRACTICE REVENUE'), findsOneWidget);
  });

  testWidgets('opens all Phase 4 modules and a medical record', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();
    final bar = find.byKey(DashboardShell.bottomNavKey);

    await tester.tap(
      find.descendant(of: bar, matching: find.text('Appointments')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search patient or service'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Cancelled'), findsWidgets);
    expect(tester.takeException(), isNull);
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: bar, matching: find.text('Patients')));
    await tester.pumpAndSettle();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    await tester.pumpAndSettle();
    expect(find.text('Search name or phone'), findsOneWidget);
    expect(find.text('All Patients (1)'), findsOneWidget);
    expect(find.text('Create Rx'), findsOneWidget);
    expect(find.text('Book Visit'), findsOneWidget);
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ananya Sharma').first);
    await tester.pumpAndSettle();
    expect(find.text('Total Visits'), findsOneWidget);
    await tester.tap(find.text('Open Medical Record'));
    await tester.pumpAndSettle();
    expect(find.text('Medical record'), findsOneWidget);
    expect(find.text('Allergies'), findsOneWidget);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Conditions'), findsOneWidget);
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    expect(find.text('Record overview'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Search name or phone'), findsOneWidget);

    await tester.tap(find.descendant(of: bar, matching: find.text('More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prescriptions'));
    await tester.pumpAndSettle();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    await tester.pumpAndSettle();
    expect(find.text('Search patient or diagnosis'), findsOneWidget);
    expect(find.text('1 total clinical record'), findsOneWidget);
    expect(find.text('Active Rx (1)'), findsOneWidget);
    expect(find.text('1 Drug prescribed'), findsOneWidget);
    expect(find.text('View Rx →'), findsOneWidget);
    await tester.tap(find.text('Ananya Sharma').first);
    await tester.pumpAndSettle();
    expect(find.text('Diagnosis'), findsOneWidget);
    expect(find.text('Medicines'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });

  testWidgets('opens Billing and Settings Phase 5 modules', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();
    final bar = find.byKey(DashboardShell.bottomNavKey);

    await tester.tap(find.descendant(of: bar, matching: find.text('More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Billing'));
    await tester.pumpAndSettle();
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Invoices'), findsWidgets);

    await tester.tap(find.descendant(of: bar, matching: find.text('More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Dr. Doctor'), findsWidgets);
    expect(find.text('Your Details'), findsOneWidget);
    expect(find.text('Editable'), findsOneWidget);
    final fullName = find.widgetWithText(TextFormField, 'Full Name');
    expect(fullName, findsOneWidget);
    expect(find.text('Dr. '), findsOneWidget);
    await tester.enterText(fullName, 'Updated Doctor');
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Map Pin'), findsOneWidget);
    expect(find.text('GST Registered'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Bank / UPI Setup'), findsOneWidget);
    expect(find.text('Automatic daily payouts for practice'), findsOneWidget);
    expect(find.text('TEST MODE'), findsOneWidget);
    expect(find.text('Bank Account'), findsOneWidget);
    expect(find.text('UPI ID'), findsWidgets);
    expect(find.text('Save Payout Details'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save Profile & Clinic Settings'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Save Profile & Clinic Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Profile saved.'), findsOneWidget);
  });

  testWidgets('opens all Phase 6 modules', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();
    final bar = find.byKey(DashboardShell.bottomNavKey);

    Future<void> openModule(String name) async {
      await tester.tap(find.descendant(of: bar, matching: find.text('More')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(name),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    await openModule('My Website');
    expect(find.text('Your public website'), findsOneWidget);
    expect(find.text('Hero Banner'), findsOneWidget);
    expect(find.text('Public Doctor Profile Header'), findsOneWidget);
    expect(find.text('VISUAL PORTRAIT'), findsOneWidget);
    expect(find.text('Live On Profile'), findsOneWidget);
    expect(find.text('Main Headlines & Messaging'), findsOneWidget);
    expect(find.text('PROFILE ACTIONS'), findsOneWidget);
    expect(find.text('Experience badge'), findsOneWidget);
    expect(find.text('COLOR THEME'), findsOneWidget);
    expect(find.text('Royal'), findsOneWidget);
    expect(find.text('Packages'), findsNothing);
    expect(tester.widget<Text>(find.text('Hero Banner')).style?.fontSize, 14);
    expect(
      tester
          .widget<Text>(find.text('Public Doctor Profile Header'))
          .style
          ?.fontSize,
      10,
    );
    expect(
      tester
          .widget<Text>(find.text('Main Headlines & Messaging'))
          .style
          ?.fontSize,
      12,
    );
    await tester.scrollUntilVisible(
      find.text('Quick Stats'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Quick Stats'));
    await tester.pumpAndSettle();
    expect(find.text('VISUAL PORTRAIT'), findsNothing);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    await tester.pumpAndSettle();
    await openModule('Blog');
    expect(find.text('Search posts or categories'), findsOneWidget);
    await openModule('Reviews');
    expect(
      find.widgetWithText(TextField, 'Search patient or keyword...'),
      findsOneWidget,
    );
    await openModule('Inquiries');
    expect(find.text('Search inquiries'), findsOneWidget);
  });

  testWidgets('creates and publishes a blog post without a saving lock', (
    tester,
  ) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(find.descendant(of: bar, matching: find.text('More')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Blog'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Blog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Post'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title *'),
      'Publishing from the app',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Rich content'),
      'A complete patient-friendly health article.',
    );
    await tester.ensureVisible(
      find.widgetWithText(SwitchListTile, 'Publish now'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Publish now'));
    await tester.ensureVisible(find.text('Create Post'));
    await tester.tap(find.text('Create Post'));
    await tester.pumpAndSettle();

    expect(find.text('Saving…'), findsNothing);
    expect(find.text('Post created.'), findsOneWidget);
    expect(find.text('Publishing from the app'), findsOneWidget);
    expect(find.text('Published'), findsWidgets);
  });

  testWidgets('downloads a generated prescription PDF', (tester) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    final downloads = _FakeFileDownloadService();
    await tester.pumpWidget(
      _testApp(preferences, fileDownloadService: downloads),
    );
    await tester.pumpAndSettle();

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(find.descendant(of: bar, matching: find.text('More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prescriptions'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Download prescription PDF'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pumpAndSettle();

    expect(downloads.savedFiles, 1);
    expect(downloads.lastFileName, endsWith('.pdf'));
    expect(downloads.lastBytes, isNotEmpty);
    expect(find.text('Prescription downloaded.'), findsOneWidget);
  });

  testWidgets('review detail sheet updates visibility and pinned state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(find.descendant(of: bar, matching: find.text('More')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reviews'));
    await tester.tap(find.text('Reviews'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ananya Sharma').first);
    await tester.pumpAndSettle();
    expect(find.text('Show'), findsOneWidget);
    expect(find.text('Unpin'), findsOneWidget);

    await tester.ensureVisible(find.text('Show'));
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Review is now visible on your website.'), findsOneWidget);

    await tester.ensureVisible(find.text('Unpin'));
    await tester.tap(find.text('Unpin'));
    await tester.pumpAndSettle();
    expect(find.text('Pin'), findsOneWidget);
    expect(find.text('Review unpinned.'), findsOneWidget);
  });

  testWidgets('opens Staff Management and Contact Support Phase 7 modules', (
    tester,
  ) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();
    final bar = find.byKey(DashboardShell.bottomNavKey);

    Future<void> openModule(String name) async {
      await tester.tap(find.descendant(of: bar, matching: find.text('More')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(name),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    await openModule('Staff Management');
    expect(find.text('Search staff or username'), findsOneWidget);
    expect(find.text('Add Staff'), findsOneWidget);
    await openModule('Contact Support');
    expect(
      find.text('Your support requests and Doctylia’s replies.'),
      findsOneWidget,
    );
    expect(find.text('New Request'), findsOneWidget);
  });

  testWidgets('blog publish and unpublish update the post status', (
    tester,
  ) async {
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(find.descendant(of: bar, matching: find.text('More')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Blog'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Blog'));
    await tester.pumpAndSettle();

    final toggle = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data == 'Publish' || widget.data == 'Unpublish'),
    );
    final before = (tester.widget(toggle.first) as Text).data;
    await tester.tap(toggle.first);
    await tester.pumpAndSettle();

    final after = (tester.widget(toggle.first) as Text).data;
    expect(after, isNot(before));
    expect(
      find.text(before == 'Publish' ? 'Post published.' : 'Post unpublished.'),
      findsOneWidget,
    );

    final firstTitle = find.descendant(
      of: find.byType(ListView).last,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.style?.fontWeight == FontWeight.w700 &&
            widget.data != 'Published' &&
            widget.data != 'Draft',
      ),
    );
    final deletedTitle = (tester.widget(firstTitle.first) as Text).data!;
    await tester.tap(find.byTooltip('Delete post').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text(deletedTitle), findsNothing);
  });

  testWidgets('reported dark-mode labels render with readable colours', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
      'theme_mode': 'dark',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    // Painted colour of a text, after theme/button style resolution.
    double luminanceOf(Finder text) {
      final paragraph = tester.renderObject<RenderParagraph>(text.first);
      Color? color;
      paragraph.text.visitChildren((span) {
        color ??= span.style?.color;
        return color == null;
      });
      return (color ?? paragraph.text.style!.color!).computeLuminance();
    }

    const readable = 0.35; // Dark card is ~0.01; light-on-dark text is >0.5.
    expect(tester.takeException(), isNull);
    expect(luminanceOf(find.text('Check\nTomorrow')), greaterThan(readable));
    await tester.scrollUntilVisible(
      find.text('View site'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(luminanceOf(find.text('View site')), greaterThan(readable));

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(find.descendant(of: bar, matching: find.text('Patients')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ananya Sharma').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Medical Record'));
    await tester.pumpAndSettle();
    // Unselected tab label (#15) and an overview card label (#16).
    expect(luminanceOf(find.text('History')), greaterThan(readable));
    expect(luminanceOf(find.text('Known allergies')), greaterThan(readable));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero, quick stats and about sections edit and save', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(find.descendant(of: bar, matching: find.text('More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Website'));
    await tester.pumpAndSettle();

    Future<void> editAndSave({
      required String section,
      required Finder field,
      required String value,
    }) async {
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, value);
      await tester.pumpAndSettle();
      final save = find.text('Save $section');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Changes saved.'), findsOneWidget, reason: section);
      expect(find.text(value), findsWidgets, reason: section);
      // Let the snackbar expire before the next section.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    Future<void> expand(String section) async {
      final header = find.text(section);
      await tester.ensureVisible(header);
      await tester.pumpAndSettle();
      await tester.tap(header);
      await tester.pumpAndSettle();
    }

    // Hero Banner is expanded by default.
    await editAndSave(
      section: 'Hero Banner',
      field: find.byType(TextFormField).first,
      value: 'Caring for every family',
    );

    await expand('Quick Stats');
    await editAndSave(
      section: 'Quick Stats',
      field: find.widgetWithText(TextFormField, 'Label').first,
      value: 'Happy Patients',
    );

    await expand('About / Doctor Profile');
    await editAndSave(
      section: 'About / Doctor Profile',
      field: find.widgetWithText(TextFormField, 'Qualifications'),
      value: 'MBBS, MD (Medicine)',
    );

    // Bug #24: a newly added service must persist through Save Services.
    await expand('Services');
    final addService = find.text('Add service');
    await tester.ensureVisible(addService);
    await tester.pumpAndSettle();
    await tester.tap(addService);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Name *'),
      'Diabetes Review',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Price ₹'), '750');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final saveServices = find.text('Save Services');
    await tester.ensureVisible(saveServices);
    await tester.pumpAndSettle();
    await tester.tap(saveServices);
    await tester.pumpAndSettle();
    expect(find.text('Changes saved.'), findsOneWidget);
    expect(find.text('Diabetes Review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a new staff member', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final preferences = FakePreferencesStore({
      'has_seen_onboarding': true,
      'mock_doctor_session': true,
      'mock_doctor_email': 'doctor@gmail.com',
    });
    await tester.pumpWidget(_testApp(preferences));
    await tester.pumpAndSettle();

    final bar = find.byKey(DashboardShell.bottomNavKey);
    await tester.tap(find.descendant(of: bar, matching: find.text('More')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Staff Management'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Staff Management'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Staff'));
    await tester.pumpAndSettle();
    Finder field(String label) => find.widgetWithText(TextField, label);
    await tester.enterText(field('Staff name *'), 'Reception Riya');
    await tester.enterText(field('Username *'), 'riya.front');
    await tester.enterText(field('Password *'), 'secret123');
    await tester.enterText(field('Confirm password *'), 'secret123');
    await tester.tap(find.text('Save Staff'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save Staff'), findsNothing);
    expect(find.text('Reception Riya'), findsOneWidget);
  });
}

Widget _testApp(
  FakePreferencesStore preferences, {
  DashboardRepository? dashboardRepository,
  FileDownloadService? fileDownloadService,
}) {
  return ProviderScope(
    overrides: [
      appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
      preferencesStoreProvider.overrideWithValue(preferences),
      doctorProfileProvider.overrideWithValue(
        DoctorProfile(
          id: 'test-doctor',
          fullName: 'Dr. Doctor',
          specialization: 'General Physician',
          consultationFee: 500,
          createdAt: DateTime(2026),
          gstRegistered: false,
          onboardingCompleted: true,
          planStatus: PlanStatus.active,
          planTier: PlanTier.premium,
          trialStart: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
      if (dashboardRepository != null)
        dashboardRepositoryProvider.overrideWithValue(dashboardRepository),
      if (fileDownloadService != null)
        fileDownloadServiceProvider.overrideWithValue(fileDownloadService),
    ],
    child: const DoctyliaApp(),
  );
}

final class _FakeFileDownloadService implements FileDownloadService {
  int savedFiles = 0;
  String? lastFileName;
  Uint8List lastBytes = Uint8List(0);

  @override
  Future<void> savePdf({
    required String fileName,
    required Uint8List bytes,
  }) async {
    savedFiles++;
    lastFileName = fileName;
    lastBytes = bytes;
  }
}
