import 'package:flip_flop/ads/ad_service.dart';
// ============================================================
// notification_service.dart
//
// Handles all push notifications for Lucky Wings:
//   - Missed day reminders            (local, predicted client-side)
//   - 5-days-left catch-up urgency    (local, predicted client-side)
//   - Raffle draw day announcement    (local reminder + FCM push)
//   - Winner congratulations          (FCM push — server-triggered, the
//                                      client can't predict who wins)
//   - Optional daily play reminder    (local)
//
// flutter_local_notifications displays everything on-device, including
// FCM messages received while the app is in the foreground (neither
// platform auto-shows a banner for those). firebase_messaging only
// supplies the token plumbing and the background/terminated delivery —
// actual Cloud Functions live in functions/index.js.
// ============================================================

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../backend/backend_service.dart';
import '../raffle/dashboard_page.dart';

/// Used to navigate from notification taps, which happen outside the
/// widget tree (background isolate / app-not-yet-built), so there's no
/// BuildContext to route with otherwise. Wired into MaterialApp in main.dart.
final navigatorKey = GlobalKey<NavigatorState>();

/// Must be a top-level (or static) function — the plugin runs it in a
/// separate background isolate when a push arrives while the app isn't
/// running. There's no UI to update here; the OS already renders the
/// notification from the payload's `notification` block.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._();

  static const _kNotifEnabled = 'notif_enabled';
  static const _kDailyReminderHour = 'notif_daily_hour';
  static const _kDailyReminderMin = 'notif_daily_min';
  static const _androidChannelId = 'high_importance_channel';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _messaging = FirebaseMessaging.instance;

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

  // ─── Notification IDs (unique per type) ───────────────────────────────────
  static const int _idMissedDay = 1001;
  static const int _idCatchUpUrgent = 1002;
  static const int _idDrawDay = 1003;
  static const int _idDailyReminder = 1005;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _androidChannelId,
          'Important Notifications',
          description: 'Raffle wins, draw day, and qualifier reminders',
          importance: Importance.high,
        ));

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _routeToDashboard());

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _routeToDashboard();
  }

  /// Triggers the OS permission prompt (Android 13+ and iOS both route
  /// through this single call in recent firebase_messaging versions).
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Call once a user is signed in — saves this device's FCM token to
  /// users/{uid} so monthlyRaffleDraw / sendDrawDayReminder can reach it,
  /// and keeps it current if the token rotates.
  Future<void> syncFcmToken(String uid) async {
    if (!await isEnabled()) return;
    await requestPermission();

    final token = await _messaging.getToken();
    if (token != null) {
      await BackendService.instance.updateFcmToken(uid, token);
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(
      (newToken) => BackendService.instance.updateFcmToken(uid, newToken),
    );
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _plugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      _notifDetails(channelId: _androidChannelId, channelName: 'Lucky Wings'),
    );
  }

  /// Set when a notification tap arrives before the app has a navigator —
  /// a cold launch from a terminated-app push is delivered (getInitialMessage)
  /// inside main(), before runApp(), and the splash screen then clears the
  /// route stack anyway. SplashScreen calls [consumePendingRoute] once it has
  /// landed on the main menu.
  bool _pendingDashboardRoute = false;

  void _routeToDashboard() {
    // The player is heading somewhere specific: no App Open ad on top of it.
    AdService.instance.noteNotificationLaunch();
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _pendingDashboardRoute = true;
      return;
    }
    nav.pushNamed(DashboardPage.routeName);
  }

  void consumePendingRoute() {
    if (!_pendingDashboardRoute) return;
    _pendingDashboardRoute = false;
    _routeToDashboard();
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    _routeToDashboard();
  }

  // ─── Preference getters/setters ───────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotifEnabled) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifEnabled, enabled);
    if (!enabled) await cancelAll();
  }

  Future<Map<String, int>> getDailyReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hour': prefs.getInt(_kDailyReminderHour) ?? 9,
      'minute': prefs.getInt(_kDailyReminderMin) ?? 0,
    };
  }

  Future<void> setDailyReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDailyReminderHour, hour);
    await prefs.setInt(_kDailyReminderMin, minute);
    await scheduleDailyReminder(hour, minute);
  }

  // ─── Schedule notifications (local, client-predicted) ─────────────────────

  /// Call the morning after a player misses a day.
  Future<void> scheduleMissedDayReminder() async {
    if (!await isEnabled()) return;
    final tomorrow9am = _nextOccurrence(hour: 9, minute: 0);
    await _plugin.zonedSchedule(
      _idMissedDay,
      '🐦 You missed yesterday!',
      'Catch up anytime this month — tap to play.',
      tz.TZDateTime.from(tomorrow9am, tz.local),
      _notifDetails(channelId: 'reminders', channelName: 'Reminders'),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Call when 5 days remain and the player has uncompleted catch-up days.
  Future<void> scheduleUrgentCatchUpReminder(int missedCount) async {
    if (!await isEnabled()) return;
    final fiveDaysLeft = _nextOccurrence(hour: 10, minute: 0);
    await _plugin.zonedSchedule(
      _idCatchUpUrgent,
      '⏰ 5 days left to catch up!',
      'You have $missedCount missed ${missedCount == 1 ? 'day' : 'days'} — play now for more entries!',
      tz.TZDateTime.from(fiveDaysLeft, tz.local),
      _notifDetails(channelId: 'urgent', channelName: 'Urgent Reminders'),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Schedule a local heads-up for draw day (1st of next month, 10 AM) —
  /// the actual FCM push on the day itself comes from sendDrawDayReminder.
  Future<void> scheduleDrawDayNotification(String drawMonthName) async {
    if (!await isEnabled()) return;
    final now = DateTime.now();
    final drawDay = DateTime(now.year, now.month + 1, 1, 10, 0);
    await _plugin.zonedSchedule(
      _idDrawDay,
      '🎉 Today is the Lucky Wings Draw!',
      'The monthly raffle is happening now — good luck!',
      tz.TZDateTime.from(drawDay, tz.local),
      _notifDetails(channelId: 'raffle', channelName: 'Raffle'),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Schedule a recurring daily reminder to play.
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    if (!await isEnabled()) return;
    await _plugin.periodicallyShow(
      _idDailyReminder,
      '🐦 Time to Flap!',
      'Don\'t forget your daily qualifier — tap to play.',
      RepeatInterval.daily,
      _notifDetails(channelId: 'daily', channelName: 'Daily Reminder'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ─── Smart scheduling ─────────────────────────────────────────────────────

  /// Call after every game session to reschedule/cancel notifications
  /// based on current state.
  Future<void> rescheduleAll({
    required bool qualifiedToday,
    required int missedCount,
    required int daysLeftInMonth,
  }) async {
    if (!await isEnabled()) return;

    if (qualifiedToday) {
      await _plugin.cancel(_idMissedDay);
    } else {
      await scheduleMissedDayReminder();
    }

    if (daysLeftInMonth <= 5 && missedCount > 0) {
      await scheduleUrgentCatchUpReminder(missedCount);
    }

    final now = DateTime.now();
    await scheduleDrawDayNotification(
        _monthName(now.month == 12 ? 1 : now.month + 1));
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  DateTime _nextOccurrence({required int hour, required int minute}) {
    final now = DateTime.now();
    var dt = DateTime(now.year, now.month, now.day, hour, minute);
    if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
    return dt;
  }

  String _monthName(int m) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[m.clamp(1, 12)];
  }

  NotificationDetails _notifDetails({
    required String channelId,
    required String channelName,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
