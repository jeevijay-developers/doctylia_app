enum FeatureKey {
  onlineConsultation('online_consultation'),
  aiBlogWriter('ai_blog_writer'),
  billingInvoices('billing_invoices'),
  patientRecords('patient_records'),
  staffManagement('staff_management');

  const FeatureKey(this.databaseKey);
  final String databaseKey;
}

class FeatureAccess {
  const FeatureAccess({
    required this.key,
    required this.effectiveEnabled,
    required this.includedByPlan,
    this.overrideEnabled,
    this.overrideActive = false,
  });

  final FeatureKey key;
  final bool effectiveEnabled;
  final bool includedByPlan;
  final bool? overrideEnabled;
  final bool overrideActive;
}

class FeatureAccessSnapshot {
  FeatureAccessSnapshot(Iterable<FeatureAccess> rows)
    : _rows = {for (final row in rows) row.key: row};

  final Map<FeatureKey, FeatureAccess> _rows;

  bool hasFeature(FeatureKey key) {
    return _rows[key]?.effectiveEnabled ?? false;
  }
}
