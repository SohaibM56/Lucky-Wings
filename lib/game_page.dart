import 'dart:async';
import 'package:flip_flop/ads/ads.dart';
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/game_painter.dart';
import 'package:flip_flop/leaderboard/leaderboard_page.dart';
import 'package:flip_flop/main.dart';
import 'package:flip_flop/my_game/my_game.dart';
import 'package:flip_flop/raffle/dashboard_page.dart';
import 'package:flip_flop/raffle/qualifier_timer_bar.dart';
import 'package:flip_flop/raffle/raffle_cubit.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flip_flop/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flip_flop/setting/setting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'game_manager.dart';

class GamePage extends StatefulWidget {
  static const routeName = "app/game";

  const GamePage({Key? key, required this.components}) : super(key: key);

  final List<Component> components;

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver
    implements GameManager {
  /// FPS
  int _frames = 0;
  bool _isInitial = false;
  bool _isPipeRemoved = true;
  bool _isPlayed = false;
  double canvasWidth = 0;
  double canvasHeight = 0;

  late final Ticker _ticker;
  late GameState _gameState;

  // late BannerAd myBanner;

  late Widget gameScorer;

  ValueNotifier<int> frameNotifier = ValueNotifier(0);
  ValueNotifier<int> scoreNotifier = ValueNotifier(0);

  late MyGameCubit _myGameCubit;
  late SettingCubit _settingCubit;
  late RaffleCubit _raffleCubit;
  bool _earnedEntryThisRun = false;
  late AdCubit _adCubit;
  bool _showCelebration = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.inGameplay = true; // no App Open ad over the game
    WidgetsBinding.instance.addObserver(this);
    _myGameCubit = context.read<MyGameCubit>();
    _settingCubit = context.read<SettingCubit>();
    _raffleCubit = context.read<RaffleCubit>();
    _adCubit = context.read<AdCubit>();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding mid-game should land on the same paused overlay a manual
    // pause does, and require the same tap-to-resume + countdown on return —
    // never silently keep playing/resume while the app was out of view.
    if (state == AppLifecycleState.paused &&
        _isInitial &&
        _gameState == GameState.play &&
        !_isPaused) {
      _pause();
    }
  }

  // FutureBuilder compares `future` by identity across rebuilds — calling
  // _initAssets() fresh inline in build() (as this used to) hands it a new
  // Future every time any setState() fires anywhere in this widget (pause,
  // resume, game over, ...), which resets it to ConnectionState.waiting and
  // flashes a spinner over the whole canvas for a frame. Creating it once
  // here and reusing the same instance fixes that.
  Future<bool>? _assetsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _assetsFuture ??= _initAssets();
  }

  Future<bool> _initAssets() async {
    if (_isInitial) return true;
    _initGame();
    gameScorer = GameScorer(
      onRestart: () {
        // Let AdCubit decide whether to show an interstitial
        final skip = _earnedEntryThisRun;
        _earnedEntryThisRun = false;
        _adCubit.onGameOver(onContinue: _initGame, skipInterstitial: skip);
      },
    );
    _ticker = this.createTicker((elapsed) {
      _frames++;
      widget.components.forEach((element) => element.update(this, _frames));
      frameNotifier.value = _frames;
    });
    _ticker.start();
    _gameState = GameState.ready;
    _isInitial = true;

    // Init Ads
    // myBanner = BannerAd(
    //   adUnitId: GameConstant.adUnits[AdUnits.banner]!,
    //   size: AdSize(width: MediaQuery.of(context).size.width.toInt(), height: 80),
    //   request: AdRequest(),
    //   listener: BannerAdListener(),
    // );
    // myBanner.load();

    return _isInitial;
  }

  bool _isPaused = false;
  int? _resumeCountdown;
  Timer? _resumeTimer;

  void _togglePauseButton() {
    _myGameCubit.playButtonSound();
    if (_isPaused) {
      // A deliberate tap on the AppBar button resumes immediately — only the
      // overlay's "tap to resume" goes through the countdown ritual.
      _resumeTimer?.cancel();
      _resumeTimer = null;
      _reallyResume();
    } else {
      _pause();
    }
  }

  void _pause() {
    _resumeTimer?.cancel();
    _resumeTimer = null;
    setState(() {
      _isPaused = true;
      _resumeCountdown = null;
    });
    _ticker.stop();
    _raffleCubit.pauseSession(); // pause qualifier timer
  }

  /// Pauses before navigating to the Leaderboard/Dashboard (or on a
  /// system/manual back-exit) so the bird doesn't keep falling off-screen —
  /// the pause overlay (with tap-to-resume + countdown) greets the player
  /// on return instead of silently resuming.
  void _pauseForNavigation() {
    if (_gameState == GameState.play && !_isPaused) _pause();
  }

  void _startResumeCountdown() {
    if (_resumeCountdown != null) return;
    setState(() => _resumeCountdown = 3);
    _resumeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resumeCountdown! <= 1) {
        timer.cancel();
        _resumeTimer = null;
        _reallyResume();
      } else {
        setState(() => _resumeCountdown = _resumeCountdown! - 1);
      }
    });
  }

  void _reallyResume() {
    setState(() {
      _isPaused = false;
      _resumeCountdown = null;
    });
    _ticker.start();
    _raffleCubit.resumeSession();
  }

  // Fixed height for the qualifier bar row below the AppBar — kept constant
  // (rather than measuring the live widget) so the canvas size never jumps
  // when the bar's content switches between the progress/qualified variants.
  static const double _qualifierBarHeight = 40;

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      backgroundColor: Colors.black54,
      elevation: 0,
      titleSpacing: 0,
      // GameScorer already renders its own back button (with a button-press
      // sound) — the default leading arrow would just duplicate it.
      automaticallyImplyLeading: false,
      title: gameScorer,
      actions: [
        PauseButton(
          isPaused: _isPaused,
          enabled: _gameState == GameState.play,
          onPressed: _togglePauseButton,
        ),
        IconButton(
          icon: const Icon(Icons.leaderboard, color: Color(0xFF00D4FF)),
          tooltip: 'Leaderboard',
          onPressed: () {
            _pauseForNavigation();
            Navigator.pushNamed(context, LeaderboardPage.routeName);
          },
        ),
        IconButton(
          icon: const Icon(Icons.dashboard, color: Color(0xFFF5A623)),
          tooltip: 'Dashboard',
          onPressed: () {
            _pauseForNavigation();
            Navigator.pushNamed(context, DashboardPage.routeName);
          },
        ),
      ],
    );

    canvasWidth = MediaQuery.of(context).size.width;
    canvasHeight = MediaQuery.of(context).size.height -
        appBar.preferredSize.height -
        _qualifierBarHeight;

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        appBar: appBar,
        body: Stack(
          children: [
            // Main game canvas
            Column(
              children: [
                SizedBox(
                  height: _qualifierBarHeight,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: const QualifierTimerBar(),
                  ),
                ),
                Expanded(
                  child: FutureBuilder(
                    future: _assetsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return GestureDetector(
                        onTap: () {
                          switch (_gameState) {
                            case GameState.ready:
                              // setState so the AppBar (pause button enabled
                              // state) picks up the transition — the canvas
                              // itself repaints via the ticker regardless.
                              setState(() => _gameState = GameState.play);
                              GetReady getReady =
                                  widget.components.last as GetReady;
                              getReady.shouldPaint = false;
                              _myGameCubit.start();
                              _raffleCubit.startSession();
                              break;
                            case GameState.play:
                              Bird bird = widget.components[4] as Bird;
                              bird.flap();
                              break;
                            default:
                              break;
                          }
                        },
                        child: ClipRect(
                          child: Container(
                            width: canvasWidth,
                            height:
                                canvasHeight - 50, // reserve space for banner
                            child: CustomPaint(
                              painter: GamePainter(
                                components: widget.components,
                                valueNotifier: frameNotifier,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Banner ad anchored at the bottom of the game
                const BannerAdWidget(),
              ],
            ),
            // Paused overlay
            if (_isPaused)
              GestureDetector(
                onTap: _resumeCountdown == null ? _startResumeCountdown : null,
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pause_circle_filled,
                          color: lightening_yellow, size: 64),
                      const SizedBox(height: 16),
                      CustomText(
                        'GAME PAUSED',
                        fontSize: 28,
                        strokeWidth: 1.2,
                        color: lightening_yellow,
                      ),
                      const SizedBox(height: 8),
                      _resumeCountdown == null
                          ? const CustomText(
                              'Tap to Resume',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            )
                          : CustomText(
                              '$_resumeCountdown',
                              fontSize: 40,
                              strokeWidth: 1.2,
                              color: lightening_yellow,
                            ),
                    ],
                  ),
                ),
              ),
            // Qualifier celebration overlay
            if (_showCelebration)
              QualifiedCelebration(
                onDismiss: () => setState(() => _showCelebration = false),
              ),
            // Listen for just-earned entry
            BlocListener<RaffleCubit, RaffleState>(
              listenWhen: (p, c) => !p.justEarnedEntry && c.justEarnedEntry,
              listener: (context, state) {
                setState(() => _showCelebration = true);
                _raffleCubit.clearJustEarned();
              },
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// Backs out of an in-progress game only after confirmation — covers both
  /// the system back gesture and GameScorer's own back button (which calls
  /// maybePop so it funnels through here too).
  Future<bool> _confirmExit() async {
    if (_gameState != GameState.play) return true;
    _pauseForNavigation();
    final height = MediaQuery.of(context).size.height / 4;
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomDialog(
        height: height,
        showCloseButton: false,
        showTitle: true,
        title: "Exit Game",
        showSecondaryButton: true,
        showPrimaryButton: true,
        secondaryText: "Cancel",
        primaryText: "Exit",
        secondaryButtonPressed: () => Navigator.pop(context, false),
        primaryButtonPressed: () => Navigator.pop(context, true),
        bodyMargin: 55,
        bodyMarginBottom: 100,
        bodyWidget: Center(
          child: CustomText(
            'Exit the game? This run\'s progress will be lost.',
            fontSize: 16,
            strokeWidth: 1.0,
            color: wood_smoke,
            borderColor: white,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
    return shouldExit ?? false;
  }

  void _initGame() {
    gameTurn++;
    if (mounted) {
      setState(() => _gameState = GameState.ready);
    } else {
      _gameState = GameState.ready;
    }
    GetReady getReady = widget.components.last as GetReady;
    getReady.shouldPaint = true;
    Bird bird = widget.components[4] as Bird;
    bird.reset();
    Board board = widget.components[3] as Board;
    board.reset();
    Obstacle obstacle = widget.components[1] as Obstacle;
    obstacle.reset();
    this._frames = 0;
    _isPlayed = false;
  }

  @override
  void dispose() {
    AdService.instance.inGameplay = false;
    WidgetsBinding.instance.removeObserver(this);
    _resumeTimer?.cancel();
    _ticker.dispose();
    // myBanner.dispose();
    super.dispose();
  }

  @override
  void gameOver() {
    setState(() => this._gameState = GameState.gameOver);
    // Capture the final run's numbers before gameOver() resets the HUD —
    // the game-over dialog already snapshots state.score itself (via its
    // own BlocListener), but these two calls read cubit state afterwards.
    final finalScore = _myGameCubit.state.score;
    final finalCoin = _myGameCubit.state.coin;
    final finalFruit = _myGameCubit.state.fruit;
    final playSeconds = _raffleCubit.currentSessionSeconds;
    _myGameCubit.gameOver(playSeconds: playSeconds);
    _raffleCubit.onGameOver(finalScore).then((_) {
      // Don't follow the "you earned an entry" celebration with an ad.
      _earnedEntryThisRun = _raffleCubit.state.justEarnedEntry;
    }); // ← save score + catchup
    _settingCubit.updateCoinAndFruit(coin: finalCoin, fruit: finalFruit);
  }

  @override
  void gameReady() => this._gameState = GameState.ready;

  @override
  GameState getGameState() => this._gameState;

  @override
  Size getScreenSize() => Size(canvasWidth, canvasHeight);

  @override
  Component getGround() => widget.components[2] as Ground;

  @override
  Component getObstacle() => widget.components[1] as Obstacle;

  @override
  int readScore() => _myGameCubit.state.score;

  @override
  void writeScore(RewardType rewardType) =>
      _myGameCubit.updateReward(rewardType: rewardType);

  @override
  void setPipeStatus(bool status) => this._isPipeRemoved = status;

  @override
  bool isPipeRemoved() => this._isPipeRemoved;

  @override
  bool isPlayed() => this._isPlayed;

  @override
  void setPlayed(bool status) => this._isPlayed = status;

  @override
  List<Item> getAvailableItems() => (widget.components[3] as Board).items;
}
