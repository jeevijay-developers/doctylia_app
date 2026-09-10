import 'package:doctylia_app/features/appointments/data/repositories/mock_appointment_repository.dart';
import 'package:doctylia_app/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appointment status summary remains unchanged during search', () async {
    final container = ProviderContainer(
      overrides: [
        appointmentRepositoryProvider.overrideWithValue(
          MockAppointmentRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final before = await container.read(appointmentSummaryProvider.future);
    container
        .read(appointmentQueryProvider.notifier)
        .setSearch('patient-that-does-not-exist');
    final after = await container.read(appointmentSummaryProvider.future);

    expect(before.total, greaterThan(0));
    expect(after.total, before.total);
    expect(after.pending, before.pending);
    expect(after.completed, before.completed);
    expect(after.cancelled, before.cancelled);
  });
}
