part of 'auth_cubit.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
  needsGoogleLink,
}

/// Which control triggered the current loading state, so the UI can show a
/// spinner on just that button instead of every button at once.
enum AuthLoadingAction { none, emailPassword, google, guest }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.loadingAction = AuthLoadingAction.none,
    this.user,
    this.error,
    this.justBecameGuest = false,
    this.conflictEmail,
    this.pendingGoogleCredential,
  });

  final AuthStatus status;
  final AuthLoadingAction loadingAction;
  final FireBaseUser? user;
  final String? error;

  /// One-shot flag set right after an automatic guest sign-in, so the UI can
  /// show a "progress isn't saved" warning once and then clear it.
  final bool justBecameGuest;

  /// Set when a Google sign-in's email already belongs to a different,
  /// pre-existing account under another provider — the UI needs to prompt
  /// for that account's password before the Google credential can be
  /// attached to it. See AuthCubit.completeGoogleLink.
  final String? conflictEmail;
  final fb_auth.AuthCredential? pendingGoogleCredential;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isGuest => user?.isAnonymous ?? false;
  bool get needsEmailVerification =>
      user != null && !user!.isAnonymous && !user!.emailVerified;
  bool get needsGoogleLink => status == AuthStatus.needsGoogleLink;

  @override
  List<Object?> get props => [
        status,
        loadingAction,
        user,
        error,
        justBecameGuest,
        conflictEmail,
        pendingGoogleCredential,
      ];

  AuthState copyWith({
    AuthStatus? status,
    AuthLoadingAction? loadingAction,
    FireBaseUser? user,
    String? error,
    bool? justBecameGuest,
    String? conflictEmail,
    fb_auth.AuthCredential? pendingGoogleCredential,
    bool clearGoogleLinkConflict = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      loadingAction: loadingAction ?? this.loadingAction,
      user: user ?? this.user,
      error: error,
      justBecameGuest: justBecameGuest ?? this.justBecameGuest,
      conflictEmail:
          clearGoogleLinkConflict ? null : (conflictEmail ?? this.conflictEmail),
      pendingGoogleCredential: clearGoogleLinkConflict
          ? null
          : (pendingGoogleCredential ?? this.pendingGoogleCredential),
    );
  }
}
