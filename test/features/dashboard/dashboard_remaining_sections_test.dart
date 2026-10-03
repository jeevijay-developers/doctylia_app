import 'package:doctylia_app/core/widgets/whatsapp_icon.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/revenue_website_cards.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/today_schedule_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remaining dashboard sections fit a narrow phone layout', (
    tester,
  ) async {
    final today = DateTime(2026, 9, 7);
    final points = List.generate(
      30,
      (index) => RevenuePoint(
        day: today.subtract(Duration(days: 29 - index)),
        amount: index == 9 ? 3500 : 120,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 344,
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    const TodayScheduleCard(
                      appointments: [],
                      totalTodayCount: 3,
                    ),
                    const SizedBox(height: 12),
                    RevenueCard(
                      points: points,
                      monthlyRevenue: 3500,
                      growthPercent: 18.4,
                    ),
                    const SizedBox(height: 12),
                    const WebsiteShareCard(
                      doctorName: 'Dr. Rajkumar',
                      websiteSlug: 'rajkumar-practice',
                      isLive: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('All appointments wrapped up for today!'), findsOneWidget);
    expect(find.text('Add Walk-in'), findsOneWidget);
    expect(find.text('Monthly Revenue'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Share Your Website'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Share Your Website'), findsOneWidget);
    expect(find.text('Share on WhatsApp'), findsOneWidget);
    expect(find.byType(WhatsAppIcon), findsOneWidget);
    final whatsappFinder = find.ancestor(
      of: find.text('Share on WhatsApp'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    final whatsapp = tester.widget<FilledButton>(whatsappFinder);
    expect(whatsapp.onPressed, isNotNull);
  });
}
