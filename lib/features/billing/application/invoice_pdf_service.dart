import 'dart:typed_data';

import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/billing/domain/entities/billing_models.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

abstract final class InvoicePdfService {
  static Future<Uint8List> generate(
    Invoice invoice,
    DoctorProfile profile,
  ) async {
    final document = pw.Document();
    final date = DateFormat('dd/MM/yyyy').format(invoice.createdAt.toLocal());
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'TAX INVOICE',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xff0d1b6e),
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'Generated via Doctylia',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _clinic(profile, invoice)),
                pw.SizedBox(width: 24),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _meta('Invoice #:', invoice.invoiceNumber),
                    pw.SizedBox(height: 5),
                    _meta('Date:', date),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 14),
            pw.Text(
              'Bill To:',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              invoice.patientName,
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 20),
            _table(invoice, profile.gstRegistered),
            pw.SizedBox(height: 30),
            pw.Text(
              'Thank you for choosing our care.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'This is a system-generated invoice.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }

  static pw.Widget _clinic(DoctorProfile profile, Invoice invoice) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Dr. ${profile.fullName ?? 'Doctor'}',
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      if (_present(profile.clinicName)) ...[
        pw.SizedBox(height: 3),
        pw.Text(profile.clinicName!, style: const pw.TextStyle(fontSize: 10)),
      ],
      if (_present(profile.address)) ...[
        pw.SizedBox(height: 3),
        pw.SizedBox(
          width: 280,
          child: pw.Text(
            profile.address!,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
      if (_present(profile.phone)) ...[
        pw.SizedBox(height: 3),
        pw.Text(
          'Phone: ${profile.phone}',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
      if (profile.gstRegistered && _present(invoice.clinicGstin)) ...[
        pw.SizedBox(height: 3),
        pw.Text(
          'GSTIN: ${invoice.clinicGstin}',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    ],
  );

  static pw.Widget _meta(String label, String value) => pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(width: 8),
      pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
    ],
  );

  static pw.Widget _table(Invoice invoice, bool gstRegistered) {
    final gstApplies = gstRegistered && invoice.gstRate > 0;
    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey200),
        bottom: pw.BorderSide(color: PdfColors.grey200),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(),
        1: pw.FixedColumnWidth(110),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xff1565c0),
          ),
          children: [
            _cell('Description', header: true),
            _cell('Amount (INR)', header: true, right: true),
          ],
        ),
        pw.TableRow(
          children: [
            _cell(invoice.serviceName),
            _cell(invoice.amount.toStringAsFixed(2), right: true),
          ],
        ),
        if (gstApplies)
          pw.TableRow(
            children: [
              _cell(
                'GST @ ${invoice.gstRate.toStringAsFixed(invoice.gstRate == invoice.gstRate.roundToDouble() ? 0 : 2)}%',
              ),
              _cell(invoice.gstAmount.toStringAsFixed(2), right: true),
            ],
          )
        else
          pw.TableRow(
            children: [
              _cell('GST Not Applicable', muted: true),
              _cell('', right: true),
            ],
          ),
        pw.TableRow(
          children: [
            _cell('Total', bold: true),
            _cell(
              invoice.totalAmount.toStringAsFixed(2),
              right: true,
              bold: true,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(
    String value, {
    bool header = false,
    bool right = false,
    bool bold = false,
    bool muted = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: pw.Text(
      value,
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: header || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: header
            ? PdfColors.white
            : muted
            ? PdfColors.grey600
            : PdfColors.grey900,
      ),
    ),
  );

  static bool _present(String? value) => value?.trim().isNotEmpty == true;
}
