import 'dart:async';

import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/inquiries/domain/entities/patient_inquiry.dart';
import 'package:doctylia_app/features/inquiries/domain/repositories/inquiry_repository.dart';
import 'package:doctylia_app/features/inquiries/presentation/providers/inquiry_providers.dart';
import 'package:doctylia_app/features/inquiries/presentation/screens/inquiries_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../support/fake_preferences_store.dart';

final _now = DateTime.now();

PatientInquiry _inquiry(
  String id,
  String name,
  InquiryStatus status,
  Duration age, {
  String? phone = '+91 98765 43210',
  String? email,
}) => PatientInquiry(
  id: id,
  name: name,
  phone: phone,
  email: email,
  message: 'Do you have an evening slot for a follow-up this week?',
  status: status,
  createdAt: _now.subtract(age),
);

/// Honors the status filter + search; [gate] holds the first load open.
final class _FakeRepository implements InquiryRepository {
  _FakeRepository({this.gate});

  final Completer<void>? gate;
  final items = [
    _inquiry(
      'n',
      'Neha New',
      InquiryStatus.newMessage,
      const Duration(minutes: 20),
      email: 'neha@example.com',
    ),
    // Opened two days ago, still unanswered → "Reply overdue".
    _inquiry('o', 'Omar Overdue', InquiryStatus.read, const Duration(days: 2)),
    _inquiry(
      'r',
      'Rhea Responded',
      InquiryStatus.responded,
      const Duration(days: 3),
      phone: null,
      email: 'rhea@example.com',
    ),
  ];

  @override
  Future<Result<PageResult<PatientInquiry>>> list(
    PageRequest page, {
    String search = '',
    InquiryStatus? status,
  }) async {
    await gate?.future;
    final term = search.trim().toLowerCase();
    final rows = items
        .where((i) => status == null || i.status == status)
        .where((i) => term.isEmpty || i.name.toLowerCase().contains(term))
        .toList();
    return Success(PageResult(items: rows, hasMore: false));
  }

  @override
  Future<Result<InquiryStats>> getStats() async =>
      const Success(InquiryStats(total: 3, newCount: 1, responded: 1));

  @override
  Future<Result<void>> setStatus(String id, InquiryStatus status) async {
    final i = items.indexWhere((item) => item.id == id);
    items[i] = items[i].copyWith(status: status);
    return const Success(null);
  }

  @override
  Stream<void> watchChanges() => const Stream.empty();
}

final class _RecordingLinks implements ExternalLinkService {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

Widget _app(InquiryRepository repository, {ExternalLinkService? links}) =>
    ProviderScope(
      overrides: [
        appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
        preferencesStoreProvider.overrideWithValue(FakePreferencesStore()),
        inquiryRepositoryProvider.overrideWithValue(repository),
        if (links != null) externalLinkServiceProvider.overrideWithValue(links),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: InquiriesScreen()),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 2000);
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('skeleton instead of spinners while loading', (tester) async {
    _phone(tester);
    final gate = Completer<void>();
    await tester.pumpWidget(_app(_FakeRepository(gate: gate)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Neha New'), findsOneWidget);
  });

  testWidgets('glance strip, statuses, overdue flag and tabs', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeRepository()));
    await tester.pumpAndSettle();

    // Awaiting reply = total − responded; response rate from real counts.
    expect(find.text('Awaiting reply'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1 unopened'), findsOneWidget);
    expect(find.text('33% answered'), findsOneWidget);

    // Card tiers: age, status/overdue badges, channel, contact meta.
    expect(find.text('20m ago'), findsOneWidget);
    expect(find.text('New'), findsWidgets); // badge + tab
    expect(find.text('Reply overdue'), findsOneWidget);
    expect(find.text('Website form'), findsNWidgets(3));
    expect(find.text('neha@example.com'), findsOneWidget);
    // Mark Responded only on unanswered cards; Book on all.
    expect(find.text('Mark Responded'), findsNWidgets(2));
    expect(find.text('Book'), findsNWidgets(3));

    // Response-time chip narrows to overdue among the loaded inquiries.
    await _tap(tester, find.text('Reply overdue (1)'));
    expect(find.text('Omar Overdue'), findsOneWidget);
    expect(find.text('Neha New'), findsNothing);
    expect(find.text('1 overdue of 3 loaded'), findsOneWidget);
    await _tap(tester, find.text('Reply overdue (1)'));

    // Status tab filters server-side.
    // Scoped to the tab bar: the stat tile is also labelled "Responded".
    await _tap(
      tester,
      find.descendant(
        of: find.byType(shadcn.Tabs),
        matching: find.text('Responded'),
      ),
    );
    expect(find.text('Rhea Responded'), findsOneWidget);
    expect(find.text('Neha New'), findsNothing);
    expect(find.text('Mark Responded'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact buttons open tel / wa.me / mailto', (tester) async {
    _phone(tester);
    final links = _RecordingLinks();
    await tester.pumpWidget(_app(_FakeRepository(), links: links));
    await tester.pumpAndSettle();
    await _tap(tester, find.byTooltip('Call').first);
    await _tap(tester, find.byTooltip('WhatsApp').first);
    await _tap(tester, find.byTooltip('Email').first);
    expect(links.opened, [
      Uri(scheme: 'tel', path: '+91 98765 43210'),
      Uri.parse('https://wa.me/919876543210'),
      Uri(scheme: 'mailto', path: 'neha@example.com'),
    ]);
  });

  testWidgets('Book opens the booking form prefilled from the inquiry', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeRepository()));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Book').first);
    expect(find.widgetWithText(TextFormField, 'Neha New'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '9876543210'), findsOneWidget);
  });

  testWidgets('empty search offers a reset', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeRepository()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No Inquiries Found'), findsOneWidget);
    await _tap(tester, find.text('Reset filters'));
    expect(find.text('Neha New'), findsOneWidget);
  });
}
