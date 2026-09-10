enum SupportTicketStatus {
  open('open', 'Open'),
  inProgress('in_progress', 'In Progress'),
  resolved('resolved', 'Resolved'),
  closed('closed', 'Closed');

  const SupportTicketStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

enum SupportPriority {
  low('low', 'Low'),
  normal('normal', 'Normal'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  const SupportPriority(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

enum SupportCategory {
  dashboard('dashboard', 'Dashboard'),
  myWebsite('my-website', 'My Website'),
  appointments('appointments', 'Appointments'),
  patients('patients', 'Patients'),
  prescriptions('prescriptions', 'Prescriptions'),
  reviews('reviews', 'Reviews'),
  blog('blog', 'Blog'),
  billing('billing', 'Billing'),
  staff('staff', 'Staff Management'),
  settings('settings', 'Settings'),
  account('account', 'Account / Login'),
  other('other', 'Other');

  const SupportCategory(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.doctorId,
    required this.subject,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    required this.submittedByName,
    this.description,
    this.category,
    this.reply,
    this.repliedAt,
    this.repliedBy,
    this.assignedTo,
    this.notes,
    this.submittedByUserId,
    this.metadata,
  });
  final String id;
  final String doctorId;
  final String subject;
  final String? description;
  final SupportTicketStatus status;
  final SupportPriority priority;
  final SupportCategory? category;
  final String? reply;
  final DateTime? repliedAt;
  final String? repliedBy;
  final String? assignedTo;
  final String? notes;
  final String submittedByName;
  final String? submittedByUserId;
  final Map<String, Object?>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SupportTicketDraft {
  const SupportTicketDraft({
    required this.subject,
    required this.description,
    required this.priority,
    required this.category,
  });
  final String subject;
  final String description;
  final SupportPriority priority;
  final SupportCategory category;
}
