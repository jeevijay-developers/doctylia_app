# Deviations and integration notes

This file records intentional differences between the Flutter implementation,
the attached product prompt, and the current web repository.

## Active

### Auth integrated; feature data remains mocked

Supabase email/password auth, password-reset email, persisted session restore,
doctor/staff role resolution, and logout are now live. Non-auth feature
repositories remain on typed mock data until their individual integration
passes. Widget tests continue to inject `MockAuthRepository`; production app
bootstrap injects `SupabaseAuthRepository`. Signup continues to the public web
signup.

### Subscription wall during screen-only mode

The route guard mirrors the web app's status and 48-hour expired-trial grace
logic. Because subscription checkout is phase 5, blocked users are currently
directed to reactivate through the web app rather than an in-app checkout.

### Phase 3 dashboard data

The dashboard reproduces the current web information architecture and uses
typed mock aggregates while backend integration is deferred. Revenue follows
the web implementation and is modeled from invoices, including a 30-day
series. The repository exposes a change stream so Supabase mode can subscribe
to appointments, patients, and invoices without introducing polling.

All approved navigation destinations are now available in the persistent
shell. Phone layouts use Home, Appointments, Patients, and More; wider layouts
switch to a navigation rail without changing routes or feature ownership.

### Phase 4 clinical modules

Appointments, patients, medical records, and prescriptions currently use
typed in-memory repositories because the approved implementation remains in
screen-only mode. Every collection screen uses 20-row, look-ahead pagination,
server-shaped search/filter queries, cached Riverpod controllers, and a
repository change-stream boundary ready for Supabase Realtime. No screen calls
Supabase directly.

Medical records are currently a typed, feature-gated overview of conditions,
medications, allergies, visits, documents, and checkup reminders. Editing
those sub-records is deferred to backend integration so the mobile forms can
follow the final RLS policies and database constraints.

Backend-dependent actions from the web app are intentionally deferred:
appointment-completion side effects (patient/invoice creation), Zoom meeting
creation, bulk deletion, file storage, and prescription PDF/export. These
must be implemented through repositories/RPCs during Supabase integration;
the mobile app will not reproduce client-side database races.

### Phase 5 billing and subscription

Billing follows the current web app rather than the older prompt table list:
persisted `invoices` are the revenue source of truth, while every transaction
row and payment-status count comes from `appointments`. The mobile repositories use
independent 20-row look-ahead pagination for transactions and invoices, cached
controllers, plan gating via `billing_invoices`, and a Realtime-ready change
stream. CSV export and generated/shareable PDF files remain deferred until the
platform-specific file and sharing implementation is approved.

Settings mirrors the web Profile, Subscription, and Account tabs, including
GST details, bank/UPI payout setup, Pro/Premium cards, appointment usage,
scheduled plan changes, cancellation, and support-mediated account deletion.
Default monthly prices follow the live web fallbacks: Pro INR 1,499 and Premium
INR 3,999.

Razorpay Checkout is represented by a typed test-mode flow during the approved
screen-only stage. It preserves the production sequence and boundaries:
create order, open checkout, verify payment/order/signature, then refresh or
schedule the plan. The official `razorpay_flutter` SDK, Edge Function calls,
live keys, webhook reconciliation, and persisted payment history will be added
only during Supabase/payment integration. No client-side action can currently
charge money.

### Phase 6 website and engagement modules

My Website follows the current web editor and uses `website_settings`,
`services`, and `working_hours` as a single bounded configuration aggregate.
The mobile editor covers hero content, themes, section visibility, services,
hours, booking limits, Premium-gated online consultations, clinic visibility,
and WhatsApp settings. Although `packages` exists in the schema and appears in
the older prompt, the current web editor does not expose package CRUD, so the
mobile app does not introduce it. Gallery and cover-image upload controls are
visible, but storage selection/upload is deferred to backend integration.

Blog, Reviews, and Inquiries each use independent 20-row look-ahead pagination,
cached Riverpod controllers, pull-to-refresh, centralized errors, and
Realtime-ready repository streams. Inquiries use the migrated
`patient_queries` table rather than an `inquiries` table and retain a defensive
empty/error state because the feature may not be enabled in every environment.
The older prompt places review visibility only in My Website, but the current
web Reviews screen supports both pinning and visibility, so mobile follows the
web behavior.

The AI Blog Writer currently returns a typed local draft and retains the web
response contract (`title`, `excerpt`, `content`, `category`) plus a 45-second
client timeout and retryable error UI. The `ai-blog-writer` Edge Function,
authentication token, rate-limit/credit errors, and live generated content are
deferred until Supabase integration. No AI request leaves the device in mock
mode.

### Phase 7 staff management and support

Staff Management mirrors the current `staff_members` schema and all 31
permission keys from `src/lib/staffPermissions.ts`. It is Premium-gated and
supports create, edit, activate/deactivate, password reset, and doctor-only
delete through typed mock repository methods. The three staff-account Edge
Functions and Supabase Auth user mutations are deferred until backend
integration; mock passwords are validated but never persisted.

Contact Support follows the current web `SupportPage` and `support_tickets`
schema. The database currently has one platform `reply` and `replied_at` pair
per ticket rather than a reply/thread table, so mobile displays that single
Doctylia response and does not invent doctor-authored ticket replies. Both
Phase 7 lists use 20-row look-ahead pagination even though the current web
screens fetch their complete lists, and both repositories expose
Realtime-ready change streams without polling.

### Phase 8 quality and performance audit

The final audit confirms that every potentially unbounded collection uses a
20-row look-ahead page contract and every list screen exposes loading, empty,
error/retry, refresh, and end-of-list behavior. Bounded configuration and
detail aggregates—dashboard schedule, website services/hours, settings tabs,
and one patient's medical-record sections—remain single loads rather than
artificially paginated lists.

Paged Riverpod controllers are intentionally not `autoDispose`, preserving
their cached rows and filters across tab switches. Repository change streams
are now consumed by the cached controllers through a serialized coordinator
that coalesces Realtime bursts; there is no polling. The shared pagination
footer also blocks concurrent page requests, preventing duplicate rows during
slow network responses.

Modal forms own and dispose their text controllers with their widget
lifecycle, mutation buttons prevent duplicate submissions, and icon-only
actions have accessibility tooltips. No presentation widget imports or calls
Supabase directly. The remaining remote-only work in this document is an
explicit backend-integration boundary, not hidden screen debt.

### Flutter/Riverpod toolchain

The workspace currently provides Flutter 3.38.5 and Dart 3.10.4. Riverpod 3.4
requires Dart 3.12, so the project pins Riverpod 3.0.3, the newest compatible
Riverpod release. Upgrade Riverpod after the Flutter SDK is upgraded.

## Backend integration blockers already identified

- The web Billing module uses appointments for transactions and invoices for
  revenue, not payments plus doctor_ledger. Mobile follows the web module.
- packages exists in the schema, but the current web My Website editor does
  not expose package CRUD.
- Support has a single platform reply on support_tickets, not a threaded
  doctor/support conversation.
- Doctor self-deletion has no doctor-authorized function; web directs the
  doctor to Contact Support.
- Online-consultation feature overrides can unlock the client gate, but the
  Zoom function and database trigger still check legacy Premium access.
- Web invoice numbering is client-generated and can race across web/mobile
  clients. An atomic backend operation should be approved before integration.

## Quality improvements over current web list behavior

All potentially unbounded mobile collections will paginate. Several current
web modules still fetch their complete collections; mobile will not copy that
scalability limitation.
