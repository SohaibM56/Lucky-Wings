/// Pure, client-side validation for the auth forms (sign up, sign in,
/// forgot password, guest-link). Runs instantly at runtime so obvious
/// mistakes (empty fields, malformed email, short password) are caught
/// before a request ever reaches Firebase — Firebase's own error codes are
/// kept as a fallback in BackendService, but shouldn't normally be hit for
/// these cases anymore.
class AuthValidators {
  AuthValidators._();

  // Deliberately simple (not RFC 5322): just enough to catch the obvious
  // "forgot the @" / "forgot the domain" mistakes without rejecting valid
  // addresses Firebase itself would accept.
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  /// For sign-in/forgot-password where any non-empty password is plausible
  /// (the account might predate a length rule change) — only blocks empty.
  static String? passwordRequired(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    return null;
  }

  /// For sign-up/guest-link where we're choosing a new password.
  static String? newPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter a password';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? username(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) return 'Enter a username';
    if (username.length < 3) return 'Username must be at least 3 characters';
    return null;
  }
}
