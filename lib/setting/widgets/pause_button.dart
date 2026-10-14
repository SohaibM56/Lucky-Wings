import 'package:flutter/cupertino.dart';

class PauseButton extends StatelessWidget {
  const PauseButton({
    required this.isPaused,
    required this.onPressed,
    this.enabled = true,
    this.width = 40,
  });

  final bool isPaused;
  final VoidCallback onPressed;
  final bool enabled;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.all(0),
      onPressed: enabled ? onPressed : null,
      child: Icon(
        isPaused
            ? const IconData(
                0xf487,
                fontFamily: CupertinoIcons.iconFont,
                fontPackage: CupertinoIcons.iconFontPackage,
              )
            : const IconData(
                0xf736,
                fontFamily: CupertinoIcons.iconFont,
                fontPackage: CupertinoIcons.iconFontPackage,
              ),
        size: 30,
        // Explicit white rather than null — this app never sets up a
        // CupertinoTheme (it's a MaterialApp), so a null color here falls
        // back to Cupertino's hardcoded default accent (iOS system blue).
        // That made the icon render blue during gameplay and then visibly
        // snap to faded white the instant the game ended (enabled flips to
        // false) — right when the Game Over dialog pops in, which is
        // exactly the "blue flicker" this was reported as.
        color: enabled
            ? CupertinoColors.white
            : CupertinoColors.white.withOpacity(0.3),
      ),
    );
  }
}
