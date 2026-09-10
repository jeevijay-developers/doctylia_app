enum StaffPermission {
  dashboardView('dashboard.view', 'View Dashboard'),
  websiteView('website.view', 'View My Website'),
  websiteEdit('website.edit', 'Edit Website'),
  websiteSettings('website.settings', 'Website Settings'),
  appointmentsView('appointments.view', 'View Appointments'),
  appointmentsCreate('appointments.create', 'Create Appointment'),
  appointmentsEdit('appointments.edit', 'Edit Appointment'),
  appointmentsCancel('appointments.cancel', 'Cancel Appointment'),
  patientsView('patients.view', 'View Patients'),
  patientsAdd('patients.add', 'Add Patient'),
  patientsEdit('patients.edit', 'Edit Patient'),
  patientsMedicalRecords(
    'patients.medical_records',
    'View Patient Medical Records',
  ),
  prescriptionsView('prescriptions.view', 'View Prescriptions'),
  prescriptionsCreate('prescriptions.create', 'Create Prescription'),
  prescriptionsEdit('prescriptions.edit', 'Edit Prescription'),
  reviewsView('reviews.view', 'View Reviews'),
  reviewsManage('reviews.manage', 'Manage Reviews'),
  blogView('blog.view', 'View Blog'),
  blogCreate('blog.create', 'Create Blog'),
  blogEdit('blog.edit', 'Edit Blog'),
  blogDelete('blog.delete', 'Delete Blog'),
  billingView('billing.view', 'View Billing'),
  billingManage('billing.manage', 'Manage Billing'),
  profileView('profile.view', 'View Profile'),
  profileEdit('profile.edit', 'Edit Profile'),
  staffView('staff.view', 'View Staff'),
  staffCreate('staff.create', 'Create Staff'),
  staffEdit('staff.edit', 'Edit Staff'),
  staffDisable('staff.disable', 'Disable Staff'),
  inquiriesView('inquiries.view', 'View Inquiries'),
  inquiriesManage('inquiries.manage', 'Manage Inquiries');

  const StaffPermission(this.key, this.label);
  final String key;
  final String label;
}

class StaffPermissionModule {
  const StaffPermissionModule(this.key, this.label, this.permissions);
  final String key;
  final String label;
  final List<StaffPermission> permissions;
}

const staffPermissionModules = [
  StaffPermissionModule('dashboard', 'Dashboard', [
    StaffPermission.dashboardView,
  ]),
  StaffPermissionModule('website', 'My Website', [
    StaffPermission.websiteView,
    StaffPermission.websiteEdit,
    StaffPermission.websiteSettings,
  ]),
  StaffPermissionModule('appointments', 'Appointments', [
    StaffPermission.appointmentsView,
    StaffPermission.appointmentsCreate,
    StaffPermission.appointmentsEdit,
    StaffPermission.appointmentsCancel,
  ]),
  StaffPermissionModule('patients', 'Patients', [
    StaffPermission.patientsView,
    StaffPermission.patientsAdd,
    StaffPermission.patientsEdit,
    StaffPermission.patientsMedicalRecords,
  ]),
  StaffPermissionModule('prescriptions', 'Prescriptions', [
    StaffPermission.prescriptionsView,
    StaffPermission.prescriptionsCreate,
    StaffPermission.prescriptionsEdit,
  ]),
  StaffPermissionModule('reviews', 'Reviews', [
    StaffPermission.reviewsView,
    StaffPermission.reviewsManage,
  ]),
  StaffPermissionModule('blog', 'Blog', [
    StaffPermission.blogView,
    StaffPermission.blogCreate,
    StaffPermission.blogEdit,
    StaffPermission.blogDelete,
  ]),
  StaffPermissionModule('billing', 'Billing', [
    StaffPermission.billingView,
    StaffPermission.billingManage,
  ]),
  StaffPermissionModule('profile', 'Profile', [
    StaffPermission.profileView,
    StaffPermission.profileEdit,
  ]),
  StaffPermissionModule('staff', 'Staff Management', [
    StaffPermission.staffView,
    StaffPermission.staffCreate,
    StaffPermission.staffEdit,
    StaffPermission.staffDisable,
  ]),
  StaffPermissionModule('inquiries', 'Inquiries', [
    StaffPermission.inquiriesView,
    StaffPermission.inquiriesManage,
  ]),
];
