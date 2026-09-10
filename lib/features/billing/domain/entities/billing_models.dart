enum BillingPaymentStatus { paid, pending, refunded, payAtClinic }

extension BillingPaymentStatusLabel on BillingPaymentStatus {
  String get label => switch (this) {
    BillingPaymentStatus.paid => 'Paid',
    BillingPaymentStatus.pending => 'Pending',
    BillingPaymentStatus.refunded => 'Refunded',
    BillingPaymentStatus.payAtClinic => 'Pay at Clinic',
  };
}

class BillingTransaction {
  const BillingTransaction({
    required this.id,
    required this.patientName,
    required this.serviceName,
    required this.date,
    required this.amount,
    required this.paymentStatus,
    required this.appointmentStatus,
    this.isMock = false,
  });
  final String id;
  final String patientName;
  final String serviceName;
  final DateTime date;
  final double amount;
  final BillingPaymentStatus paymentStatus;
  final String appointmentStatus;
  final bool isMock;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.patientName,
    required this.serviceName,
    required this.amount,
    required this.gstRate,
    required this.gstAmount,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.appointmentId,
    this.clinicGstin,
  });
  final String id;
  final String invoiceNumber;
  final String patientName;
  final String serviceName;
  final double amount;
  final double gstRate;
  final double gstAmount;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final String? appointmentId;
  final String? clinicGstin;
}

class BillingSummary {
  const BillingSummary({
    required this.todayRevenue,
    required this.weekRevenue,
    required this.monthRevenue,
    required this.paidCount,
    required this.pendingCount,
    required this.payAtClinicCount,
    required this.refundedCount,
  });
  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final int paidCount;
  final int pendingCount;
  final int payAtClinicCount;
  final int refundedCount;
}

class BillingQuery {
  const BillingQuery({
    this.search = '',
    this.paymentStatus,
    this.startDate,
    this.endDateExclusive,
  });

  factory BillingQuery.currentMonth([DateTime? value]) {
    final date = value ?? DateTime.now();
    return BillingQuery(
      startDate: DateTime(date.year, date.month),
      endDateExclusive: DateTime(date.year, date.month + 1),
    );
  }

  final String search;
  final BillingPaymentStatus? paymentStatus;
  final DateTime? startDate;
  final DateTime? endDateExclusive;
}
