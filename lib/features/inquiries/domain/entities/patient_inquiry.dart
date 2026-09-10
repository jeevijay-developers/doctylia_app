enum InquiryStatus { newMessage, read, responded }

extension InquiryStatusLabel on InquiryStatus {
  String get label => switch (this) {
    InquiryStatus.newMessage => 'New',
    InquiryStatus.read => 'Read',
    InquiryStatus.responded => 'Responded',
  };
}

class PatientInquiry {
  const PatientInquiry({
    required this.id,
    required this.name,
    required this.message,
    required this.status,
    required this.createdAt,
    this.phone,
    this.email,
  });
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String message;
  final InquiryStatus status;
  final DateTime createdAt;
  PatientInquiry copyWith({InquiryStatus? status}) => PatientInquiry(
    id: id,
    name: name,
    phone: phone,
    email: email,
    message: message,
    status: status ?? this.status,
    createdAt: createdAt,
  );
}

class InquiryStats {
  const InquiryStats({
    required this.total,
    required this.newCount,
    required this.responded,
  });
  final int total;
  final int newCount;
  final int responded;
}
