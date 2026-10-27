import 'package:doctylia_app/app/app_flavor.dart';
import 'package:doctylia_app/bootstrap.dart';

// Remote flavor: any repository provider that bootstrap does not override
// throws instead of silently serving mock data.
Future<void> main() => bootstrap(flavor: AppFlavor.production);
