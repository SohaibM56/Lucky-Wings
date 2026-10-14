import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../backend/backend_service.dart';
import '../notifications/notification_service.dart';
import '../setting/setting.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';
import 'auth_cubit.dart';
import 'auth_page.dart';

/// Single destination for everything account-related — username, email
/// verification status, linking a guest session, and signing out. Reached
/// by tapping the username/account pill on the main menu header, which
/// used to carry a separate logout icon and verify-email icon of its own.
class AccountPage extends StatelessWidget {
  static const routeName = 'app/account';

  const AccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: transparentStatusBarDark,
      child: Scaffold(
        body: Stack(
          children: [
            // Same background image as the main menu so this reads as part
            // of the same screen stack rather than a jarring context switch.
            const _AccountBackground(),
            SafeArea(
              child: Column(
                children: [
                  _AccountAppBar(),
                  Expanded(
                    child: BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AccountCard(state: state),
                              const SizedBox(height: 20),
                              if (!state.isGuest &&
                                  state.needsEmailVerification) ...[
                                _VerifyEmailCard(),
                                const SizedBox(height: 20),
                              ],
                              // Available for guests too — missed-day/
                              // catch-up reminders are scheduled locally
                              // and don't require a real account.
                              const _NotificationToggleCard(),
                              const SizedBox(height: 20),
                              if (state.isGuest)
                                _LinkAccountButton()
                              else
                                _LogoutButton(),
                              const SizedBox(height: 28),
                              _DeleteAccountButton(isGuest: state.isGuest),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountBackground extends StatelessWidget {
  const _AccountBackground();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingCubit, SettingState>(
      buildWhen: (pre, cur) => pre.currentMap != cur.currentMap,
      builder: (context, state) {
        return Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(state.currentMap.sprites.first),
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: ShapeDecoration(
                color: lightening_yellow,
                shadows: [BoxShadow(color: wood_smoke, offset: Offset(0, 4))],
                shape:
                    CircleBorder(side: BorderSide(color: wood_smoke, width: 2)),
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.black87, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          const CustomText('ACCOUNT', fontSize: 24, strokeWidth: 1.0),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.state});

  final AuthState state;

  @override
  Widget build(BuildContext context) {
    final username = state.user?.username;
    final email = state.user?.email;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: Colors.white,
        shadows: [BoxShadow(color: wood_smoke, offset: Offset(0, 4))],
        shape: RoundedRectangleBorder(
          side: BorderSide(color: wood_smoke, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: ShapeDecoration(
                  color: lightening_yellow,
                  shape: CircleBorder(
                      side: BorderSide(color: wood_smoke, width: 2)),
                ),
                child: const Icon(Icons.person, color: Colors.black87, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      state.isGuest
                          ? 'Guest player'
                          : (username?.isNotEmpty == true
                              ? username!
                              : 'Player'),
                      fontSize: 20,
                      strokeWidth: 0.75,
                      color: wood_smoke,
                      borderColor: Colors.transparent,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.isGuest
                          ? 'Progress isn\'t saved yet'
                          : (email ?? ''),
                      style: TextStyle(
                        color: wood_smoke.withOpacity(0.6),
                        fontFamily: 'DiloWorld',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!state.isGuest) ...[
            const SizedBox(height: 16),
            _VerificationBadge(verified: state.user?.emailVerified ?? false),
          ],
        ],
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? const Color(0xFF2E7D32) : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verified ? Icons.verified : Icons.error_outline,
              color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            verified ? 'Email verified' : 'Email not verified',
            style: TextStyle(
              color: color,
              fontFamily: 'DiloWorld',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Notification on/off switch. Wraps NotificationService, which already
/// handles the actual OS permission request (Android 13+'s runtime
/// POST_NOTIFICATIONS prompt via firebase_messaging; auto-granted at
/// install time on Android 8–12, which is this app's full supported range
/// per minSdkVersion 27) and local-notification scheduling — this widget
/// is just the UI for flipping NotificationService.isEnabled()/setEnabled().
class _NotificationToggleCard extends StatefulWidget {
  const _NotificationToggleCard();

  @override
  State<_NotificationToggleCard> createState() =>
      _NotificationToggleCardState();
}

class _NotificationToggleCardState extends State<_NotificationToggleCard> {
  final _service = NotificationService.instance;
  bool? _enabled; // null while the initial read is in flight
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service.isEnabled().then((value) {
      if (mounted) setState(() => _enabled = value);
    });
  }

  Future<void> _onChanged(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (value) {
        // requestPermission() is a no-op prompt-wise on Android 8–12
        // (permission is already granted at install time there) and
        // triggers the real system dialog on Android 13+ / iOS. Either
        // way it resolves to whether notifications can actually show.
        final granted = await _service.requestPermission();
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Notifications are blocked — enable them for Lucky Wings in your device settings to turn this on.'),
          ));
          return; // leave _enabled/the switch as it was (off)
        }
        await _service.setEnabled(true);
        final uid = context.read<AuthCubit>().state.user?.uid;
        if (uid != null) await _service.syncFcmToken(uid);
      } else {
        await _service.setEnabled(false);
      }
      if (mounted) setState(() => _enabled = value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: ShapeDecoration(
        color: Colors.white,
        shadows: [BoxShadow(color: wood_smoke, offset: Offset(0, 4))],
        shape: RoundedRectangleBorder(
          side: BorderSide(color: wood_smoke, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.notifications_active : Icons.notifications_off,
            color: wood_smoke,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: wood_smoke,
                    fontFamily: 'DiloWorld',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Reminders for missed days and the raffle draw',
                  style: TextStyle(
                    color: wood_smoke.withOpacity(0.6),
                    fontFamily: 'DiloWorld',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _busy || _enabled == null
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              : Switch(
                  value: enabled,
                  activeThumbColor: lightening_yellow,
                  activeTrackColor: wood_smoke,
                  onChanged: _onChanged,
                ),
        ],
      ),
    );
  }
}

class _VerifyEmailCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: Colors.white,
        shadows: [BoxShadow(color: wood_smoke, offset: Offset(0, 4))],
        shape: RoundedRectangleBorder(
          side: BorderSide(color: wood_smoke, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Please verify your email to secure your account.',
            style: TextStyle(
              color: wood_smoke,
              fontFamily: 'DiloWorld',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    context.read<SettingCubit>().playButtonSound();
                    await context.read<AuthCubit>().resendVerificationEmail();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Verification email sent — check your inbox.')));
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: wood_smoke, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Resend',
                      style: TextStyle(
                          color: wood_smoke,
                          fontFamily: 'DiloWorld',
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    context.read<SettingCubit>().playButtonSound();
                    await context.read<AuthCubit>().refreshEmailVerification();
                    final stillPending =
                        context.read<AuthCubit>().state.needsEmailVerification;
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(stillPending
                          ? 'Still not verified — check your inbox for the link.'
                          : 'Email verified, thanks!'),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightening_yellow,
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: wood_smoke, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Verified',
                      style: TextStyle(
                          fontFamily: 'DiloWorld', fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkAccountButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () {
          context.read<SettingCubit>().playButtonSound();
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AuthPage(isLinking: true)));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: lightening_yellow,
          foregroundColor: Colors.black87,
          side: BorderSide(color: wood_smoke, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.link),
        label: const Text('LINK ACCOUNT',
            style: TextStyle(fontFamily: 'DiloWorld', fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Matches _LinkAccountButton's filled yellow / dark-outline style — it
    // previously used OutlinedButton (transparent fill), which looked out
    // of place next to every other button on this screen.
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () => _confirmLogout(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: lightening_yellow,
          foregroundColor: Colors.black87,
          side: BorderSide(color: wood_smoke, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.logout),
        label: const Text('LOGOUT',
            style: TextStyle(fontFamily: 'DiloWorld', fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    context.read<SettingCubit>().playButtonSound();
    showDialog(
      context: context,
      builder: (_) {
        final height = MediaQuery.of(context).size.height / 4;
        return CustomDialog(
          height: height,
          showCloseButton: false,
          showTitle: true,
          title: "Log Out",
          showSecondaryButton: true,
          showPrimaryButton: true,
          secondaryText: "Cancel",
          primaryText: "Logout",
          secondaryButtonPressed: () => Navigator.pop(context),
          primaryButtonPressed: () async {
            Navigator.pop(context);
            await context.read<AuthCubit>().signOut();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                  AuthPage.routeName, (route) => false);
            }
          },
          bodyMargin: 55,
          bodyMarginBottom: 100,
          bodyWidget: Center(
            child: CustomText(
              'Are you sure you want to log out?',
              fontSize: 18,
              strokeWidth: 0.15,
              color: wood_smoke,
              borderColor: white,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

/// "Delete account" — required by Google Play for any app with sign-up.
/// Deletes the profile, scores, raffle entries and the sign-in itself (Cloud
/// Function `deleteAccount`); raffle winner history is kept without any
/// personal details. Password users re-enter their password and Google users
/// pick their account again first, because the server only accepts a
/// sign-in from the last few minutes. Guests have nothing to confirm.
class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.isGuest});

  final bool isGuest;

  static const _danger = Color(0xFFB3261E);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => _start(context),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _danger,
          side: const BorderSide(color: _danger, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.delete_forever),
        label: const Text('DELETE ACCOUNT',
            style: TextStyle(fontFamily: 'DiloWorld', fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    context.read<SettingCubit>().playButtonSound();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CustomDialog(
        height: MediaQuery.of(context).size.height / 2.6,
        showCloseButton: false,
        showTitle: true,
        title: "Delete Account",
        showSecondaryButton: true,
        showPrimaryButton: true,
        secondaryText: "Cancel",
        primaryText: "Delete",
        actionButtonFontSize: 18,
        secondaryButtonPressed: () => Navigator.pop(dialogContext, false),
        primaryButtonPressed: () => Navigator.pop(dialogContext, true),
        bodyMargin: 55,
        bodyMarginBottom: 100,
        bodyWidget: Center(
          child: CustomText(
            isGuest
                ? 'This permanently deletes this guest account: your scores, coins, unlocks and raffle entries. This cannot be undone.'
                : 'This permanently deletes your account, email, scores, coins, unlocks and raffle entries. This cannot be undone.',
            fontSize: 15,
            strokeWidth: 0.15,
            color: wood_smoke,
            borderColor: white,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final cubit = context.read<AuthCubit>();
    String? password;
    if (BackendService.instance.signInMethod == 'password') {
      password = await _askPassword(context);
      if (password == null || !context.mounted) return;
    }

    // Blocking progress dialog while the server deletes everything.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator(color: Color(0xFFF5A623))),
      ),
    );
    final error = await cubit.deleteAccount(password: password);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // progress dialog

    if (error != null) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AuthPage.routeName, (route) => false);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted')));
  }

  Future<String?> _askPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Confirm your password',
            style: TextStyle(color: Colors.white, fontFamily: 'DiloWorld')),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Password',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Delete account',
                style: TextStyle(color: Color(0xFFFF4D6D))),
          ),
        ],
      ),
    );
  }
}
