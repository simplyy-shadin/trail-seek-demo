import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'engine/rope_models.dart';

/// Vibration, sound and a system notification for Digital Rope alerts, so a
/// leader with the phone in a pocket still feels "1 member is falling behind".
class RopeAlerts {
  RopeAlerts._();
  static final instance = RopeAlerts._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  final Map<String, RopeState> _lastState = {};
  final Map<String, DateTime> _lastAt = {};
  static const _duplicateCooldown = Duration(seconds: 45);

  static const _channel = AndroidNotificationChannel(
    'rope_alerts',
    'Digital Rope alerts',
    description: 'Members falling behind or separated from the group',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Lost member / SOS: alarm sound on the alarm stream (plays even on silent
  /// notification volume), long vibration, repeated until it is cleared.
  static final _alarm = AndroidNotificationChannel(
    'rope_alarm',
    'Digital Rope alarms',
    description: 'A member is lost or needs help: alarm sound and vibration until you check',
    importance: Importance.max,
    playSound: true,
    sound: const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 900, 400, 900, 400, 900, 400, 1500]),
  );

  /// Android Notification.FLAG_INSISTENT: sound and vibration repeat until cancelled or opened.
  static final _insistent = Int32List.fromList([4]);

  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      await android?.createNotificationChannel(_alarm);
      _ready = true;
    } catch (e) {
      debugPrint('RopeAlerts init failed: $e');
    }
  }

  /// Ask for permission right before a session starts (pre-start checklist).
  Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? true;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return await ios.requestPermissions(alert: true, sound: true, badge: false) ?? true;
    } catch (_) {}
    return true;
  }

  /// Settings → Group alerts off: only safety alarms (separated, critical,
  /// SOS, Stop, you are left behind) still notify.
  bool quiet = false;

  Future<void> memberChanged(String memberName, RopeState to, {String? memberId}) async {
    if (quiet && (to == RopeState.weak || to == RopeState.fallingBehind || to == RopeState.connected)) return;
    final key = memberId ?? memberName;
    final now = DateTime.now();
    final previous = _lastState[key];
    if (previous == to && now.difference(_lastAt[key] ?? now) < _duplicateCooldown) return;
    // A late recovery packet must not announce recovery if we never warned.
    if (to == RopeState.connected && (previous == null || previous == RopeState.connected)) return;
    _lastState[key] = to;
    _lastAt[key] = now;
    final notificationId = key.hashCode & 0x7fffffff;
    if (to == RopeState.connected) {
      await _cancel(notificationId);
      await _show(notificationId, 'Connection restored', '$memberName is connected to the group again.');
      return;
    }
    final (title, body) = switch (to) {
      RopeState.weak => ('Weak Bluetooth connection', '$memberName’s connection is weakening. Keep the group together.'),
      RopeState.fallingBehind => ('1 member is falling behind', '$memberName is getting separated from the group. Wait or check on them.'),
      RopeState.separated => ('$memberName is separated', 'No contact for a minute. Stop the group and check the last-known position.'),
      RopeState.critical => ('CRITICAL: $memberName missing', 'No reconnection in the escalation window. Stop the group now.'),
      _ => ('', ''),
    };
    // Display the OS notification immediately; the haptic sequence must not
    // delay a locked phone's alert by up to 1.5 seconds.
    unawaited(_buzz(strong: to == RopeState.separated || to == RopeState.critical));
    await _show(notificationId, title, body, critical: to == RopeState.critical, alarm: to == RopeState.separated || to == RopeState.critical);
  }

  Future<void> selfIsolated(bool isolated) async {
    const id = 7;
    if (!isolated) {
      await _cancel(id);
      return;
    }
    unawaited(_buzz(strong: true));
    await _show(id, 'Your group is moving away', 'Most of the group has gone quiet. Catch up or send "Wait for me".', alarm: true);
  }

  Future<void> groupMessage(String from, String text, {bool alarm = false}) async {
    if (quiet && !alarm) return;
    unawaited(_buzz(strong: alarm));
    await _show(900 + from.hashCode % 100, from, text, alarm: alarm);
  }

  /// A *GPS-estimated* group spacing warning. Independent of BLE state, so a
  /// healthy heartbeat never incorrectly cancels a distance warning.
  /// It is intentionally NOT a missing-person SOS and must never be phrased as
  /// a precise distance measurement; nearby phones may have poor GPS accuracy.
  Future<void> distanceWarning(String memberId, String memberName,
      {required double estimatedMetres, required bool urgent}) async {
    if (quiet && !urgent) return;
    final id = ('gps-spacing:$memberId').hashCode & 0x7fffffff;
    final rounded = (estimatedMetres / 25).round() * 25;
    unawaited(_buzz(strong: urgent));
    await _show(id, urgent ? 'Group spacing is increasing' : 'Check your group spacing',
      '$memberName is approximately ${rounded}m away by GPS. '
      'Pause and visually check your group; the estimate may be inaccurate.',
      alarm: urgent);
  }

  Future<void> distanceRestored(String memberId) async {
    await _cancel(('gps-spacing:$memberId').hashCode & 0x7fffffff);
  }

  Future<void> clearAll() async {
    _lastState.clear();
    _lastAt.clear();
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<void> _buzz({required bool strong}) async {
    try {
      if (strong) {
        for (var i = 0; i < 6; i++) {
          await HapticFeedback.vibrate();
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      } else {
        await HapticFeedback.mediumImpact();
      }
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  Future<void> _show(int id, String title, String body, {bool critical = false, bool alarm = false}) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            alarm ? _alarm.id : _channel.id,
            alarm ? _alarm.name : _channel.name,
            channelDescription: alarm ? _alarm.description : _channel.description,
            sound: alarm ? _alarm.sound : null,
            audioAttributesUsage: alarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
            additionalFlags: alarm ? _insistent : null,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: critical,
            ongoing: critical,
            vibrationPattern: alarm ? _alarm.vibrationPattern : Int64List.fromList([0, 300, 150, 300]),
            color: const Color(0xFF9DFF1E),
            ticker: title,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true, interruptionLevel: InterruptionLevel.timeSensitive),
        ),
      );
    } catch (e) {
      debugPrint('RopeAlerts show failed: $e');
    }
  }

  Future<void> _cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }
}
