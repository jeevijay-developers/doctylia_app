import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/billing/application/invoice_pdf_service.dart';
import 'package:doctylia_app/features/billing/domain/entities/billing_models.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a GST invoice PDF from profile and invoice fields', () async {
    final date = DateTime(2026, 8, 31);
    final profile = DoctorProfile(
      id: 'doctor-id',
      consultationFee: 700,
      createdAt: date,
      gstRegistered: true,
      onboardingCompleted: true,
      planStatus: PlanStatus.active,
      planTier: PlanTier.pro,
      trialStart: date,
      updatedAt: date,
      fullName: 'Aarav Shah',
      clinicName: 'Doctylia Clinic',
      address: '12 Health Avenue, Mumbai',
      phone: '9876543210',
      gstin: '27ABCDE1234F1Z5',
    );
    final invoice = Invoice(
      id: 'invoice-id',
      invoiceNumber: 'INV-2026-0001',
      patientName: 'Ananya Sharma',
      serviceName: 'General Consultation',
      amount: 700,
      gstRate: 18,
      gstAmount: 126,
      totalAmount: 826,
      status: 'generated',
      createdAt: date,
      clinicGstin: '27ABCDE1234F1Z5',
    );

    final bytes = await InvoicePdfService.generate(invoice, profile);

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
