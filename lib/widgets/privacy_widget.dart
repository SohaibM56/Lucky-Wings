import 'package:flip_flop/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hosted pages (Firebase Hosting, same project as the backend). Keep these in
/// step with `hosting/privacy-policy.html` and `hosting/delete-account.html`.
const String kPrivacyPolicyUrl = 'https://lucky-wings-1535f.web.app/privacy-policy';
const String kDeleteAccountUrl = 'https://lucky-wings-1535f.web.app/delete-account';

/// Short, accurate summary shown from the main menu. The full policy lives on
/// the web page so it can be updated without shipping a new app version.
class PrivacyWidget extends StatelessWidget {
  const PrivacyWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final body = TextStyle(
      fontSize: 15,
      color: wood_smoke,
      fontWeight: FontWeight.w500,
      height: 1.35,
    );
    final heading = TextStyle(
      fontSize: 16,
      color: wood_smoke,
      fontWeight: FontWeight.w800,
    );
    return Scrollbar(
      thumbVisibility: true,
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('What we collect', style: heading),
          const SizedBox(height: 4),
          Text(
            'If you create an account: your email and display name. For every player: scores, '
            'play time and raffle entries, which are used to run the daily goal, the leaderboard '
            'and the monthly prize draw, and a push token if you allow reminders. '
            'Guests are identified only by a random ID.',
            style: body,
          ),
          const SizedBox(height: 12),
          Text('Ads', style: heading),
          const SizedBox(height: 4),
          Text(
            'The app shows ads from Google AdMob, which may use your advertising ID. '
            'Where required (EU, UK, Switzerland) you are asked for consent first. '
            'Rewarded ads are always optional.',
            style: body,
          ),
          const SizedBox(height: 12),
          Text('Your control', style: heading),
          const SizedBox(height: 4),
          Text(
            'You can turn reminders off and delete your account and data at any time '
            'in Account → Delete account.',
            style: body,
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => _open(context, kPrivacyPolicyUrl),
              child: const Text(
                'Read the full privacy policy',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link')),
      );
    }
  }
}
