import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';

enum AuthStatus {
  unauthenticated,
  authenticatedDoctor,
  staffRejected,
  accountError,
}

class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.isSubmitting = false,
    this.errorMessage,
  });

  const AuthState.unauthenticated({
    bool isSubmitting = false,
    String? errorMessage,
  }) : this(
         status: AuthStatus.unauthenticated,
         isSubmitting: isSubmitting,
         errorMessage: errorMessage,
       );

  const AuthState.authenticated(DoctorSession session)
    : this(status: AuthStatus.authenticatedDoctor, session: session);

  const AuthState.staffRejected() : this(status: AuthStatus.staffRejected);

  const AuthState.accountError([String? message])
    : this(status: AuthStatus.accountError, errorMessage: message);

  final AuthStatus status;
  final DoctorSession? session;
  final bool isSubmitting;
  final String? errorMessage;
}
