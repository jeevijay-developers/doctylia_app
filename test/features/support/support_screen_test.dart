import 'dart:async';

import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/support/domain/entities/support_faq.dart';
import 'package:doctylia_app/features/support/domain/entities/support_ticket.dart';
import 'package:doctylia_app/features/support/domain/repositories/support_repository.dart';
import 'package:doctylia_app/features/support/presentation/providers/support_providers.dart';
import 'package:doctylia_app/features/support/presentation/screens/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _ticket = SupportTicket(
  id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  doctorId: 'doctor',
  subject: 'Invoice PDF shows the wrong GST number',
  status: SupportTicketStatus.inProgress,
  priority: SupportPriority.high,
  category: SupportCategory.billing,
  createdAt: DateTime(2026, 10, 20),
  updatedAt: DateTime(2026, 10, 21),
  submittedByName: 'Dr. Meera',
);

final class _FakeRepository implements SupportRepository {
  _FakeRepository({this.gate, this.tickets});

  final Completer<void>? gate;
  final List<SupportTicket>? tickets;

  @override
  Future<Result<PageResult<SupportTicket>>> list(PageRequest page) async {
    await gate?.future;
    return Success(PageResult(items: tickets ?? [_ticket], hasMore: false));
  }

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingLinks implements ExternalLinkService {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

Widget _app(SupportRepository repository, {ExternalLinkService? links}) =>
    ProviderScope(
      overrides: [
        appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
        supportRepositoryProvider.overrideWithValue(repository),
        if (links != null) externalLinkServiceProvider.overrideWithValue(links),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const SupportScreen()),
    );

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 3200);
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'Doctylia',
      packageName: 'com.doctylia.app',
      version: '1.0.0',
      buildNumber: '7',
      buildSignature: '',
    ),
  );

  test('every help category has articles; contacts match the web', () {
    for (final category in FaqCategory.values) {
      expect(
        supportFaqs.where((f) => f.category == category),
        isNotEmpty,
        reason: category.label,
      );
    }
    expect(SupportContacts.email, 'support@doctylia.com');
    expect(SupportContacts.phone, '+91 86194 83010');
  });

  testWidgets('ticket skeleton instead of a spinner', (tester) async {
    _phone(tester);
    final gate = Completer<void>();
    await tester.pumpWidget(_app(_FakeRepository(gate: gate)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text(_ticket.subject), findsOneWidget);
  });

  testWidgets('contact tiles, ticket card and version line', (tester) async {
    _phone(tester);
    final links = _RecordingLinks();
    await tester.pumpWidget(_app(_FakeRepository(), links: links));
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip('Call +91 86194 83010'));
    await _tap(tester, find.byTooltip('Email support@doctylia.com'));
    expect(links.opened, [
      Uri(scheme: 'tel', path: '+918619483010'),
      Uri(scheme: 'mailto', path: 'support@doctylia.com'),
    ]);

    // 3-tier ticket: short ref from the real id, status, tags, reply state.
    expect(find.text('#A1B2C3D4'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('High priority'), findsOneWidget);
    expect(find.text('1 open'), findsOneWidget);
    expect(find.textContaining('Awaiting reply'), findsOneWidget);

    // Follow-up reuses the existing request sheet, prefilled with "Re:".
    await _tap(tester, find.text('Follow-up'));
    expect(find.text('Re: ${_ticket.subject}'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Doctylia v1.0.0 (7)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('raise a ticket opens the request form', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeRepository(tickets: const [])));
    await tester.pumpAndSettle();
    expect(find.text('No requests yet'), findsOneWidget);
    await _tap(tester, find.byTooltip('Raise a support ticket'));
    expect(find.text('New Request'), findsOneWidget);
  });

  testWidgets('FAQ search, categories and accordion', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeRepository()));
    await tester.pumpAndSettle();

    const question = 'How do I renew a prescription?';
    final answer = supportFaqs.firstWhere((f) => f.question == question).answer;

    // Category tab narrows the list.
    await _tap(tester, find.text('EMR & Prescriptions'));
    expect(find.text(question), findsOneWidget);
    expect(find.text('How do I log in?'), findsNothing);

    // Accordion expands to reveal the answer.
    expect(find.text(answer), findsNothing);
    await _tap(tester, find.text(question));
    expect(find.text(answer), findsOneWidget);

    // Search with no hits offers a reset.
    await _tap(tester, find.text('All topics'));
    await tester.enterText(find.byType(TextField), 'zzz-no-match');
    await tester.pumpAndSettle();
    expect(find.text('No matching articles'), findsOneWidget);
    await _tap(tester, find.text('Reset filters'));
    expect(find.text('How do I log in?'), findsOneWidget);
  });
}
