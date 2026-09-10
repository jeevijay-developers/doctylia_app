sealed class AppFailure implements Exception {
  const AppFailure(this.userMessage, {this.cause, this.stackTrace});

  final String userMessage;
  final Object? cause;
  final StackTrace? stackTrace;
}

final class AuthFailure extends AppFailure {
  const AuthFailure(super.userMessage, {super.cause, super.stackTrace});
}

final class SessionExpiredFailure extends AppFailure {
  const SessionExpiredFailure()
    : super('Your session has expired. Please log in again.');
}

final class PermissionFailure extends AppFailure {
  const PermissionFailure()
    : super('You do not have permission to perform this action.');
}

final class PlanRestrictedFailure extends AppFailure {
  const PlanRestrictedFailure(String featureName)
    : super('Upgrade your plan to use $featureName.');
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.userMessage, {super.cause});
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.cause, super.stackTrace})
    : super(
        'We could not connect. Check your internet connection and try again.',
      );
}

final class RateLimitFailure extends AppFailure {
  const RateLimitFailure()
    : super('Too many attempts. Please wait a moment and try again.');
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure(super.userMessage, {super.cause});
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([
    super.userMessage = 'The requested item was not found.',
  ]);
}

final class ServerFailure extends AppFailure {
  const ServerFailure({super.cause, super.stackTrace})
    : super('Something went wrong on our side. Please try again.');
}

final class RemoteServiceFailure extends AppFailure {
  const RemoteServiceFailure(
    super.userMessage, {
    super.cause,
    super.stackTrace,
  });
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.cause, super.stackTrace})
    : super('Something went wrong. Please try again.');
}
