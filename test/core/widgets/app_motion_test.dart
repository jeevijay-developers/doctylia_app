import 'package:doctylia_app/core/widgets/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required bool motion, bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: AppMotion(
        enabled: motion,
        child: AppEntrance(
          index: 2,
          child: AppCountUp(value: 1250, format: (v) => '₹${v.round()}'),
        ),
      ),
    ),
  );
}

void main() {
  testEntranceDecidedAtMount();

  testWidgets('counts up from 0 and lands on the exact value', (tester) async {
    await tester.pumpWidget(_host(motion: true));
    expect(find.text('₹0'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('₹1250'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('₹1250'), findsOneWidget);
  });

  testWidgets('reduce-motion shows final values immediately', (tester) async {
    await tester.pumpWidget(_host(motion: true, reduceMotion: true));
    expect(find.text('₹1250'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('motion off (skeleton) renders statically', (tester) async {
    await tester.pumpWidget(_host(motion: false));
    expect(find.text('₹1250'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}

Widget _entranceHost({required bool enabled}) => MaterialApp(
  home: AppMotion(
    enabled: true,
    child: AppEntrance(index: 0, enabled: enabled, child: const Text('card')),
  ),
);

void testEntranceDecidedAtMount() {
  testWidgets('entrance is decided at mount; rebuilds never start it', (
    tester,
  ) async {
    // Already-shown list card: mounts without animating…
    await tester.pumpWidget(_entranceHost(enabled: false));
    expect(tester.hasRunningAnimations, isFalse);
    // …and a later rebuild with enabled: true doesn't replay it.
    await tester.pumpWidget(_entranceHost(enabled: true));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
