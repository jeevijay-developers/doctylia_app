import 'dart:io';

import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/billing/application/invoice_pdf_service.dart';
import 'package:doctylia_app/features/billing/domain/entities/billing_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void showInvoiceSheet(BuildContext context, Invoice invoice) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: _InvoiceView(invoice: invoice),
        ),
      ),
    );

class _InvoiceView extends ConsumerStatefulWidget {
  const _InvoiceView({required this.invoice});
  final Invoice invoice;

  @override
  ConsumerState<_InvoiceView> createState() => _InvoiceViewState();
}

class _InvoiceViewState extends ConsumerState<_InvoiceView> {
  bool generating = false;

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final profile = ref.watch(doctorProfileProvider);
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final gstApplies = profile?.gstRegistered == true && invoice.gstRate > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Invoice Preview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. ${profile?.fullName ?? 'Doctor'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  if (_present(profile?.clinicName)) Text(profile!.clinicName!),
                  if (_present(profile?.address)) Text(profile!.address!),
                  if (_present(profile?.phone))
                    Text('Phone: ${profile!.phone}'),
                  if (profile?.gstRegistered == true &&
                      _present(invoice.clinicGstin))
                    Text('GSTIN: ${invoice.clinicGstin}'),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Invoice #'),
                Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(DateFormat('d MMM yyyy').format(invoice.createdAt)),
              ],
            ),
          ],
        ),
        const Divider(height: AppSpacing.xl),
        Text('BILL TO', style: Theme.of(context).textTheme.labelSmall),
        Text(
          invoice.patientName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Container(
                color: AppColors.primary,
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Description',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'Amount (INR)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _AmountRow(invoice.serviceName, money.format(invoice.amount)),
              _AmountRow(
                gstApplies
                    ? 'GST @ ${invoice.gstRate.toStringAsFixed(0)}%'
                    : 'GST Not Applicable',
                gstApplies ? money.format(invoice.gstAmount) : '',
                muted: !gstApplies,
              ),
              _AmountRow(
                'Total',
                money.format(invoice.totalAmount),
                strong: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: generating || profile == null ? null : _sharePdf,
            icon: generating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(generating ? 'Generating...' : 'Share Invoice PDF'),
          ),
        ),
      ],
    );
  }

  Future<void> _sharePdf() async {
    final profile = ref.read(doctorProfileProvider);
    if (profile == null || generating) return;
    setState(() => generating = true);
    try {
      final bytes = await InvoicePdfService.generate(widget.invoice, profile);
      final directory = await getTemporaryDirectory();
      final safeNumber = widget.invoice.invoiceNumber.replaceAll(
        RegExp('[^a-zA-Z0-9_-]+'),
        '-',
      );
      final path = '${directory.path}${Platform.pathSeparator}$safeNumber.pdf';
      await File(path).writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'application/pdf')],
          subject: 'Invoice ${widget.invoice.invoiceNumber}',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate the invoice PDF.')),
        );
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  static bool _present(String? value) => value?.trim().isNotEmpty == true;
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(
    this.label,
    this.value, {
    this.strong = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool strong;
  final bool muted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w700 : null,
              color: muted ? Theme.of(context).hintColor : null,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: strong ? FontWeight.w700 : null),
        ),
      ],
    ),
  );
}
