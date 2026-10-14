import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_validators.dart';
import '../setting/setting.dart';

class AuthPage extends StatefulWidget {
  static const routeName = 'app/auth';

  /// When true, this page upgrades the current guest session into a real
  /// account instead of showing the sign in / guest flow.
  final bool isLinking;

  const AuthPage({Key? key, this.isLinking = false}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late bool _isSignUp = widget.isLinking;
  // Reassigned (not final) on every sign-up/sign-in toggle so the Form
  // remounts with fresh FormFieldStates — see the comment at the Form
  // below for why that's needed.
  var _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  // Validators only run once a submit has been attempted — otherwise every
  // field would show "Enter your email" etc. the instant the page opens,
  // before the user has typed anything.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: BlocListener<AuthCubit, AuthState>(
          // authenticated only counts when it follows a real attempt
          // (loading); reset() re-emitting it after an error must not
          // navigate away.
          listenWhen: (p, c) =>
              p.status != c.status &&
              !(c.status == AuthStatus.authenticated &&
                  p.status != AuthStatus.loading),
          listener: (context, state) {
            if (state.needsGoogleLink) {
              _showLinkGoogleDialog(context, state.conflictEmail!);
              return;
            }
            if (!state.isAuthenticated) return;
            if (widget.isLinking) {
              Navigator.pop(context);
              return;
            }
            final components = context.read<SettingCubit>().state.components;
            Navigator.pushReplacementNamed(context, SettingPage.routeName,
                arguments: components);
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Center(
                    child: Column(children: [
                      Image.asset(
                        'assets/images/logo/lucky_wings_icon.png',
                        width: 90,
                        height: 90,
                      ),
                      const SizedBox(height: 8),
                      const Text('LUCKY WINGS',
                          style: TextStyle(
                              fontFamily: 'DiloWorld',
                              fontSize: 28,
                              color: Color(0xFFF5A623),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _isSignUp
                            ? (widget.isLinking
                                ? 'Save your progress with a real account'
                                : 'Create your account')
                            : 'Welcome back!',
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                            fontFamily: 'DiloWorld'),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 48),

                  // Form
                  if (_isSignUp) ...[
                    _label('USERNAME'),
                    const SizedBox(height: 6),
                    _input(
                      controller: _usernameCtrl,
                      hint: 'Your display name',
                      icon: Icons.person,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _emailFocus.requestFocus(),
                      validator: AuthValidators.username,
                    ),
                    const SizedBox(height: 16),
                  ],

                  _label('EMAIL'),
                  const SizedBox(height: 6),
                  _input(
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    hint: 'your@email.com',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    validator: AuthValidators.email,
                  ),
                  const SizedBox(height: 16),

                  _label('PASSWORD'),
                  const SizedBox(height: 6),
                  _input(
                    controller: _passwordCtrl,
                    focusNode: _passwordFocus,
                    hint: '••••••••',
                    icon: Icons.lock,
                    obscure: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: _isSignUp
                        ? AuthValidators.newPassword
                        : AuthValidators.passwordRequired,
                    suffix: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white38),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),

                  if (!_isSignUp) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text('Forgot password?',
                            style: TextStyle(
                                color: Colors.white54,
                                fontFamily: 'DiloWorld',
                                fontSize: 12)),
                      ),
                    ),
                  ],
                  if (widget.isLinking && !_isSignUp) ...[
                    const Text(
                      'Signing in to an existing account switches to it. '
                      "This guest's progress won't be merged.",
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFamily: 'DiloWorld'),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Error
                  BlocBuilder<AuthCubit, AuthState>(
                    buildWhen: (p, c) => p.error != c.error,
                    builder: (context, state) {
                      if (state.error == null) return const SizedBox.shrink();
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D6D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFFF4D6D).withOpacity(0.4)),
                        ),
                        child: Text(state.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFFFF4D6D),
                                fontSize: 13,
                                fontFamily: 'DiloWorld')),
                      );
                    },
                  ),

                  // Submit button
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      return SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5A623),
                            foregroundColor: Colors.black,
                            // Same reasoning as the Google button below —
                            // disabled (while Google sign-in is loading)
                            // would otherwise fall back to the theme's
                            // default grey/low-contrast disabled colors.
                            disabledBackgroundColor:
                                const Color(0xFFF5A623).withOpacity(0.5),
                            disabledForegroundColor:
                                Colors.black.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: state.isLoading ? null : _submit,
                          child: state.loadingAction ==
                                  AuthLoadingAction.emailPassword
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(_isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                                  style: const TextStyle(
                                      fontFamily: 'DiloWorld',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: Divider(color: Colors.white.withOpacity(0.1))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR',
                          style:
                              TextStyle(color: Colors.white30, fontSize: 11)),
                    ),
                    Expanded(
                        child: Divider(color: Colors.white.withOpacity(0.1))),
                  ]),
                  const SizedBox(height: 16),

                  // Google sign-in
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      return SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            // Without this, the button's disabled state
                            // (triggered whenever ANY auth action is
                            // loading, not just Google's) falls back to the
                            // theme's default disabled color instead of
                            // white — nearly invisible on this dark
                            // background, making the text look "cleared".
                            disabledForegroundColor:
                                Colors.white.withOpacity(0.5),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.2)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: state.isLoading
                              ? null
                              : () =>
                                  context.read<AuthCubit>().signInWithGoogle(),
                          child: state.loadingAction == AuthLoadingAction.google
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.g_mobiledata, size: 28),
                                    SizedBox(width: 4),
                                    Text('Continue with Google',
                                        style: TextStyle(
                                            fontFamily: 'DiloWorld',
                                            fontSize: 14)),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),

                  ...[
                    const SizedBox(height: 20),

                    // Toggle
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isSignUp = !_isSignUp;
                          _autovalidateMode = AutovalidateMode.disabled;
                          // A fresh GlobalKey remounts the Form (and every
                          // field's FormFieldState) instead of reusing the
                          // old one — otherwise the username field
                          // inserting above shifts email/password down a
                          // slot while their stale error text stays
                          // attached to the same Element, so it visually
                          // ends up under the wrong field.
                          _formKey = GlobalKey<FormState>();
                          context.read<AuthCubit>().reset();
                        }),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontFamily: 'DiloWorld', fontSize: 13),
                            children: [
                              TextSpan(
                                text: _isSignUp
                                    ? 'Already have an account? '
                                    : "Don't have an account? ",
                                style: const TextStyle(color: Colors.white54),
                              ),
                              TextSpan(
                                text: _isSignUp ? 'Sign In' : 'Sign Up',
                                style: const TextStyle(
                                    color: Color(0xFFF5A623),
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (!widget.isLinking) ...[
                      const SizedBox(height: 40),

                      // Skip (guest mode)
                      Center(
                        child: TextButton(
                          onPressed: _skipToGame,
                          child: const Text('Play as Guest',
                              style: TextStyle(
                                  color: Colors.white30,
                                  fontFamily: 'DiloWorld',
                                  fontSize: 12)),
                        ),
                      ),
                    ],
                  ],
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    // Dismiss the keyboard immediately — otherwise it stays up through the
    // loading spinner and any error banner, covering part of the form.
    FocusScope.of(context).unfocus();
    // Switch to autovalidate on the first submit attempt so, if validation
    // fails here, the error(s) also update live as the user fixes them —
    // without this they'd only re-check on the next tap of the button.
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final username = _usernameCtrl.text.trim();

    if (widget.isLinking && _isSignUp) {
      context.read<AuthCubit>().linkGuestAccount(
          email: email, password: password, username: username);
    } else if (_isSignUp) {
      context
          .read<AuthCubit>()
          .signUp(email: email, password: password, username: username);
    } else {
      context.read<AuthCubit>().signIn(email: email, password: password);
    }
  }

  void _skipToGame() {
    context.read<AuthCubit>().continueAsGuest();
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final dialogFormKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Reset password',
              style: TextStyle(color: Colors.white, fontFamily: 'DiloWorld')),
          content: Form(
            key: dialogFormKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: AuthValidators.email,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'your@email.com',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                errorStyle: const TextStyle(color: Color(0xFFFF4D6D)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                FocusScope.of(dialogContext).unfocus();
                if (!dialogFormKey.currentState!.validate()) return;
                final email = emailCtrl.text.trim();
                Navigator.pop(dialogContext);
                try {
                  await context.read<AuthCubit>().sendPasswordReset(email);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Password reset email sent — check your inbox.')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Could not send reset email: $e')));
                }
              },
              child: const Text('Send',
                  style: TextStyle(color: Color(0xFFF5A623))),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkGoogleDialog(BuildContext context, String email) {
    final passwordCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    bool obscure = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Account already exists',
              style: TextStyle(color: Colors.white, fontFamily: 'DiloWorld')),
          content: Form(
            key: dialogFormKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$email already has an account. Sign in with its password to link Google for next time.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  autofocus: true,
                  validator: AuthValidators.passwordRequired,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    errorStyle: const TextStyle(color: Color(0xFFFF4D6D)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white38),
                      onPressed: () =>
                          setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.read<AuthCubit>().cancelGoogleLink();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (!dialogFormKey.currentState!.validate()) return;
                context
                    .read<AuthCubit>()
                    .completeGoogleLink(passwordCtrl.text);
                Navigator.pop(dialogContext);
              },
              child: const Text('Sign In & Link',
                  style: TextStyle(color: Color(0xFFF5A623))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontFamily: 'DiloWorld',
            fontSize: 11,
            color: Colors.white38,
            letterSpacing: 1.2),
      );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontFamily: 'DiloWorld'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        errorStyle: const TextStyle(
            color: Color(0xFFFF4D6D), fontFamily: 'DiloWorld', fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF5A623)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4D6D)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4D6D), width: 1.5),
        ),
      ),
    );
  }
}
