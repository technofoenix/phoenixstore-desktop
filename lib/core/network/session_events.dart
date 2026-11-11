import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set when the API rejects the session because the account was disabled,
/// frozen or is still pending. The shell is replaced by a blocking screen.
class AccountBlockedNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void block(String message) => state = message;

  void reset() => state = null;
}

final accountBlockedProvider =
    NotifierProvider<AccountBlockedNotifier, String?>(
      AccountBlockedNotifier.new,
    );

/// Bumped when the refresh token is rejected: the stored session is cleared
/// and [AuthController] returns to the login screen.
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void expire() => state++;
}

final sessionExpiredProvider = NotifierProvider<SessionExpiredNotifier, int>(
  SessionExpiredNotifier.new,
);
