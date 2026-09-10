import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_access_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    required this.feature,
    required this.child,
    required this.lockedChild,
    super.key,
  });

  final FeatureKey feature;
  final Widget child;
  final Widget lockedChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(featureAccessProvider).hasFeature(feature)
        ? child
        : lockedChild;
  }
}
