import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/prescriptions/application/prescription_pdf_service.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a PDF with structured prescription data', () async {
    final now = DateTime(2026, 8, 31);
    final profile = DoctorProfile(
      id: 'doctor-id',
      consultationFee: 500,
      createdAt: now,
      gstRegistered: false,
      onboardingCompleted: true,
      planStatus: PlanStatus.active,
      planTier: PlanTier.premium,
      trialStart: now,
      updatedAt: now,
      fullName: 'Aarav Shah',
      clinicName: 'Doctylia Clinic',
      qualifications: 'MBBS',
      specialization: 'General Medicine',
      registrationNumber: 'REG-123',
      slug: 'dr-aarav-shah',
    );
    final prescription = Prescription(
      id: 'prescription-id',
      patientId: 'patient-id',
      patientName: 'Ananya Sharma',
      date: now,
      diagnosis: 'Viral fever',
      patientAge: 31,
      patientWeight: 58,
      medicines: const [
        MedicineItem(
          name: 'Paracetamol',
          strength: '500 mg',
          frequency: 'Twice daily',
          duration: '5 days',
          timing: 'After food',
          route: 'Oral',
          instructions: 'Drink plenty of water',
        ),
      ],
      advice: 'Rest well',
      followUpDate: DateTime(2026, 9, 5),
    );

    final bytes = await PrescriptionPdfService.generate(
      profile: profile,
      prescription: prescription,
      details: const PrescriptionSlipDetails(
        patientGender: 'female',
        vitals: {'blood_pressure': '120/80', 'pulse': 72},
      ),
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
