/// In-app help articles for doctors.
///
/// DRAFT — written from the app's current behavior and the web's published
/// facts (contacts, hours, trial length, security wording). Review and edit
/// before release; answers must stay in step with the product.
library;

/// Official support contacts, as published on the web's contact section.
abstract final class SupportContacts {
  static const phone = '+91 86194 83010';
  static const email = 'support@doctylia.com';
  static const hours = 'Mon–Sat, 9 AM – 7 PM IST';
  static const responseTime = '2–4 hours';
}

enum FaqCategory {
  general('General'),
  billing('Billing & Subscriptions'),
  appointments('Appointments'),
  prescriptions('EMR & Prescriptions'),
  account('Account & Security');

  const FaqCategory(this.label);
  final String label;
}

class SupportFaq {
  const SupportFaq(this.category, this.question, this.answer);

  final FaqCategory category;
  final String question;
  final String answer;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q.isEmpty ||
        question.toLowerCase().contains(q) ||
        answer.toLowerCase().contains(q);
  }
}

const supportFaqs = [
  // ── General ─────────────────────────────────────────────────────────
  SupportFaq(
    FaqCategory.general,
    'How do I reach Doctylia support?',
    'Raise a ticket from this screen, email ${SupportContacts.email}, or '
        'call ${SupportContacts.phone}. We are available '
        '${SupportContacts.hours} and typically reply within '
        '${SupportContacts.responseTime}.',
  ),
  SupportFaq(
    FaqCategory.general,
    'Why does my follow-up appear as a new request?',
    'Each support request holds one reply from our team. When you send a '
        'follow-up, it is raised as a new "Re:" request so the support team '
        'sees it straight away.',
  ),
  SupportFaq(
    FaqCategory.general,
    'Are changes in the app synced with my web dashboard?',
    'Yes. The app and the web dashboard use the same account and data, so '
        'appointments, patients, prescriptions and settings stay in sync.',
  ),
  SupportFaq(
    FaqCategory.general,
    'How do I collect more patient reviews?',
    'Open Reviews and tap "Share Link" to send your review link to patients '
        'after a visit. You can pin your best reviews or hide any review from '
        'your public website.',
  ),

  // ── Billing & Subscriptions ─────────────────────────────────────────
  SupportFaq(
    FaqCategory.billing,
    'What happens when my free trial ends?',
    'Your 7-day trial gives full access. When it ends, choose a plan in '
        'Settings → Subscription. Your data is kept; during the grace period '
        'the app is read-only until you upgrade.',
  ),
  SupportFaq(
    FaqCategory.billing,
    'How are online consultation payments settled?',
    'For online payments, Doctylia keeps the platform service charge and '
        'routes the rest to your linked Razorpay account, which settles to '
        'your bank on a T+2 business-day schedule. "Pay at Clinic" '
        'appointments have no platform charge.',
  ),
  SupportFaq(
    FaqCategory.billing,
    'Where can I find GST invoices?',
    'Go to Billing → Invoices. An invoice is created once a payment is '
        'marked paid; open it to view the breakdown or share the PDF.',
  ),
  SupportFaq(
    FaqCategory.billing,
    'Can I export my transactions?',
    'Yes. In Billing → Transactions, tap the export icon next to search. It '
        'shares a CSV of the transactions matching your current filters.',
  ),

  // ── Appointments ────────────────────────────────────────────────────
  SupportFaq(
    FaqCategory.appointments,
    'Why is my appointments list empty?',
    'Appointments opens on today\'s date. Tap "All" in the date strip, or '
        '"Show all dates", to see every appointment.',
  ),
  SupportFaq(
    FaqCategory.appointments,
    'Can I turn a website inquiry into an appointment?',
    'Yes. In Inquiries, tap "Book" on an inquiry. The booking form opens '
        'with the patient\'s name, phone, email and message filled in.',
  ),

  // ── EMR & Prescriptions ─────────────────────────────────────────────
  SupportFaq(
    FaqCategory.prescriptions,
    'How do I renew a prescription?',
    'Tap "Renew" on a prescription card. A new prescription opens with the '
        'same patient, diagnosis and medicines, dated today. The original '
        'prescription is not changed.',
  ),
  SupportFaq(
    FaqCategory.prescriptions,
    'How do I send a prescription to a patient?',
    'Use the share icon on the prescription card to send the PDF over '
        'WhatsApp, email or any app, or the download icon to save it.',
  ),
  SupportFaq(
    FaqCategory.prescriptions,
    'What do Active, Follow-up due and Completed mean?',
    'Active: issued today or with an upcoming follow-up. Follow-up due: the '
        'follow-up date is within the next 3 days or was missed in the last '
        '14. Completed: an earlier course with no pending follow-up.',
  ),

  // ── Account & Security ──────────────────────────────────────────────
  SupportFaq(
    FaqCategory.account,
    'How do I log in?',
    'Use your registered mobile number — we send a one-time code by SMS. '
        'Older accounts can also use "Doctor / Clinic Staff Login" with email '
        'and password.',
  ),
  SupportFaq(
    FaqCategory.account,
    'Can my clinic staff use this app?',
    'The app is for doctors. Staff members use the web dashboard, with the '
        'access you give them in Staff Management.',
  ),
  SupportFaq(
    FaqCategory.account,
    'Is my patient data secure?',
    'We use enterprise-grade encryption and secure cloud hosting, and '
        'comply with Indian data protection standards.',
  ),
];
