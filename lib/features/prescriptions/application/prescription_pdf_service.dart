import 'dart:io';

import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

abstract final class PrescriptionPdfService {
  static const royal = PdfColor.fromInt(0xff1d4ed8);

  static Future<Uint8List> generate({
    required DoctorProfile profile,
    required Prescription prescription,
    required PrescriptionSlipDetails details,
  }) async {
    final doctorName = _doctorDisplayName(profile.fullName);
    final inter = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter.ttf'));
    final signature = await _networkImage(profile.signatureUrl);
    final document = pw.Document(
      title: 'Prescription ${prescription.id}',
      author: profile.fullName ?? 'Doctor',
    );
    final clinicName =
        profile.clinicName ??
        (profile.fullName == null ? 'Clinic' : '$doctorName Clinic');
    final qualification = [
      profile.qualifications,
      profile.specialization,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' - ');
    final address = [
      profile.address,
      profile.city,
      profile.state,
    ].whereType<String>().where((value) => value.isNotEmpty).join(', ');
    final website = profile.slug == null
        ? 'https://doctylia.com'
        : 'https://doctylia.com/dr/${profile.slug}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: inter,
          bold: inter,
          italic: inter,
          boldItalic: inter,
        ),
        build: (_) => [
          _header(profile, qualification),
          pw.Container(height: 2, color: royal),
          pw.SizedBox(height: 16),
          _patientBox(prescription, details),
          if (details.vitals.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _vitals(details.vitals),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            'Rx',
            style: pw.TextStyle(
              color: royal,
              fontSize: 30,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          _medicines(prescription),
          if (_hasAdvice(prescription)) ...[
            pw.SizedBox(height: 18),
            pw.Divider(color: PdfColors.grey300),
            _advice(prescription),
          ],
          pw.SizedBox(height: 32),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: _signature(profile, qualification, signature),
          ),
          pw.SizedBox(height: 22),
          _footer(clinicName, address, profile, website),
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _header(DoctorProfile profile, String qualification) =>
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 42,
            height: 42,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: royal, width: 2),
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Text(
              '+',
              style: pw.TextStyle(
                color: royal,
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _doctorDisplayName(profile.fullName),
                  style: pw.TextStyle(
                    color: royal,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (qualification.isNotEmpty)
                  pw.Text(
                    qualification,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                if (profile.registrationNumber?.isNotEmpty ?? false)
                  pw.Text(
                    'Reg. No.: ${profile.registrationNumber}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (profile.phone?.isNotEmpty ?? false)
                pw.Text(profile.phone!, style: const pw.TextStyle(fontSize: 9)),
              if (profile.clinicEmail?.isNotEmpty ?? false)
                pw.Text(
                  profile.clinicEmail!,
                  style: const pw.TextStyle(fontSize: 9),
                ),
            ],
          ),
        ],
      );

  static pw.Widget _patientBox(
    Prescription rx,
    PrescriptionSlipDetails details,
  ) {
    final left = <String, String>{
      'Patient Name': rx.patientName,
      'Age': rx.patientAge?.toString() ?? '-',
      'Gender': details.patientGender ?? '-',
      'Weight': rx.patientWeight == null
          ? '-'
          : '${_number(rx.patientWeight!)} kg',
      'Diagnosis': rx.diagnosis ?? '-',
      if (details.visitReason?.isNotEmpty ?? false)
        'Complaint': details.visitReason!,
      if (details.symptoms?.isNotEmpty ?? false) 'Symptoms': details.symptoms!,
    };
    final right = <String, String>{
      'Date': DateFormat('yyyy-MM-dd').format(rx.date),
      'Prescription ID': rx.id
          .substring(0, rx.id.length.clamp(0, 8))
          .toUpperCase(),
      if (rx.patientId != null)
        'Patient ID': rx.patientId!
            .substring(0, rx.patientId!.length.clamp(0, 8))
            .toUpperCase(),
    };
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: royal, width: 1.5),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              children: left.entries
                  .map((entry) => _info(entry.key, entry.value))
                  .toList(),
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              children: right.entries
                  .map((entry) => _info(entry.key, entry.value))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _info(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 78,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Text(': ', style: const pw.TextStyle(fontSize: 8.5)),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 1),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 8.5)),
          ),
        ),
      ],
    ),
  );

  static pw.Widget _vitals(Map<String, dynamic> values) {
    final chips = <String>[
      if (values['blood_pressure'] != null) 'BP: ${values['blood_pressure']}',
      if (values['pulse'] != null) 'Pulse: ${values['pulse']} bpm',
      if (values['temperature'] != null) 'Temp: ${values['temperature']} F',
      if (values['respiratory_rate'] != null)
        'RR: ${values['respiratory_rate']}/min',
      if (values['spo2'] != null) 'SpO2: ${values['spo2']}%',
      if (values['height'] != null) 'Height: ${values['height']} cm',
      if (values['bmi'] != null) 'BMI: ${values['bmi']}',
    ];
    return pw.Wrap(
      spacing: 6,
      runSpacing: 5,
      children: chips
          .map(
            (value) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xffeff6ff),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                value,
                style: const pw.TextStyle(fontSize: 8, color: royal),
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _medicines(Prescription rx) {
    if (rx.medicines.isEmpty) {
      return pw.Text(
        rx.legacyMedications ?? 'No medications recorded',
        style: const pw.TextStyle(fontSize: 11),
      );
    }
    return pw.Column(
      children: rx.medicines.indexed.map((entry) {
        final medicine = entry.$2;
        final attributes = <String>[
          if (medicine.frequency.isNotEmpty) 'Dosage: ${medicine.frequency}',
          if (medicine.duration.isNotEmpty) 'Duration: ${medicine.duration}',
          if (medicine.timing.isNotEmpty) 'Timing: ${medicine.timing}',
          if (medicine.route.isNotEmpty) 'Route: ${medicine.route}',
        ];
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 11),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${entry.$1 + 1}. ${medicine.name}${medicine.strength.isEmpty ? '' : ' - ${medicine.strength}'}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (attributes.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 13, top: 2),
                  child: pw.Text(
                    attributes.join('  |  '),
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              if (medicine.instructions.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 13, top: 2),
                  child: pw.Text(
                    medicine.instructions,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static bool _hasAdvice(Prescription rx) =>
      [
        rx.advice,
        rx.dietAdvice,
        rx.lifestyleAdvice,
        rx.followUpInstructions,
      ].any((value) => value?.isNotEmpty ?? false) ||
      rx.followUpDate != null;

  static pw.Widget _advice(Prescription rx) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (rx.advice?.isNotEmpty ?? false)
        _section('GENERAL ADVICE', rx.advice!),
      if (rx.dietAdvice?.isNotEmpty ?? false)
        _section('DIET ADVICE', rx.dietAdvice!),
      if (rx.lifestyleAdvice?.isNotEmpty ?? false)
        _section('LIFESTYLE ADVICE', rx.lifestyleAdvice!),
      if (rx.followUpDate != null ||
          (rx.followUpInstructions?.isNotEmpty ?? false))
        _section(
          'FOLLOW-UP',
          [
            if (rx.followUpDate != null)
              DateFormat('yyyy-MM-dd').format(rx.followUpDate!),
            rx.followUpInstructions,
          ].whereType<String>().join(' - '),
        ),
    ],
  );

  static pw.Widget _section(String title, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 7),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9.5)),
      ],
    ),
  );

  static pw.Widget _signature(
    DoctorProfile profile,
    String qualification,
    pw.MemoryImage? signature,
  ) => pw.SizedBox(
    width: 160,
    child: pw.Column(
      children: [
        if (signature != null)
          pw.Image(signature, height: 36, fit: pw.BoxFit.contain)
        else
          pw.SizedBox(height: 30),
        pw.Divider(color: PdfColors.grey500),
        pw.Text(
          'Signature',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          _doctorDisplayName(profile.fullName),
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        if (qualification.isNotEmpty)
          pw.Text(
            qualification,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        if (profile.registrationNumber?.isNotEmpty ?? false)
          pw.Text(
            'Reg. No.: ${profile.registrationNumber}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
      ],
    ),
  );

  static pw.Widget _footer(
    String clinicName,
    String address,
    DoctorProfile profile,
    String website,
  ) => pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: royal, width: 1.5),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Clinic Address',
                  style: pw.TextStyle(
                    color: royal,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  clinicName,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (address.isNotEmpty)
                  pw.Text(address, style: const pw.TextStyle(fontSize: 8)),
                if (profile.phone?.isNotEmpty ?? false)
                  pw.Text(
                    profile.phone!,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                if (profile.clinicEmail?.isNotEmpty ?? false)
                  pw.Text(
                    profile.clinicEmail!,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
              ],
            ),
          ),
        ),
        pw.Container(
          width: 1,
          height: 92,
          color: const PdfColor.fromInt(0xffbfdbfe),
        ),
        pw.SizedBox(
          width: 150,
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(9),
            child: pw.Column(
              children: [
                pw.Text(
                  'Scan to visit our website',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: royal,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: website,
                  width: 55,
                  height: 55,
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Doctylia',
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static Future<pw.MemoryImage?> _networkImage(String? source) async {
    if (source == null || source.isEmpty) return null;
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(source));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final bytes = await response.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );
      return pw.MemoryImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static String _doctorDisplayName(String? value) {
    final name = (value ?? '')
        .replaceFirst(RegExp(r'^\s*dr\.?\s*', caseSensitive: false), '')
        .trim();
    return name.isEmpty ? 'Doctor' : 'Dr. $name';
  }
}
