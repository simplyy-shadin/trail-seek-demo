import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/units.dart';
import '../../data/models/activity_record.dart';

enum CommunityVisibility { public, followers }

@immutable
class AppSettings {
  const AppSettings({
    this.metric = true,
    this.notifyGroupAlerts = true,
    this.notifyCommunity = true,
    this.weeklySummary = false,
    this.shareLocationInGroups = true,
    this.communityVisibility = CommunityVisibility.public,
    this.analyticsConsent = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        metric: j['metric'] as bool? ?? true,
        notifyGroupAlerts: j['notifyGroupAlerts'] as bool? ?? true,
        notifyCommunity: j['notifyCommunity'] as bool? ?? true,
        weeklySummary: j['weeklySummary'] as bool? ?? false,
        shareLocationInGroups: j['shareLocationInGroups'] as bool? ?? true,
        communityVisibility: CommunityVisibility.values.firstWhere((v) => v.name == j['communityVisibility'], orElse: () => CommunityVisibility.public),
        analyticsConsent: j['analyticsConsent'] as bool? ?? false,
      );

  final bool metric;
  final bool notifyGroupAlerts;
  final bool notifyCommunity;
  final bool weeklySummary;
  final bool shareLocationInGroups;
  final CommunityVisibility communityVisibility;
  final bool analyticsConsent;

  Units get units => Units(metric: metric);

  AppSettings copyWith({
    bool? metric,
    bool? notifyGroupAlerts,
    bool? notifyCommunity,
    bool? weeklySummary,
    bool? shareLocationInGroups,
    CommunityVisibility? communityVisibility,
    bool? analyticsConsent,
  }) =>
      AppSettings(
        metric: metric ?? this.metric,
        notifyGroupAlerts: notifyGroupAlerts ?? this.notifyGroupAlerts,
        notifyCommunity: notifyCommunity ?? this.notifyCommunity,
        weeklySummary: weeklySummary ?? this.weeklySummary,
        shareLocationInGroups: shareLocationInGroups ?? this.shareLocationInGroups,
        communityVisibility: communityVisibility ?? this.communityVisibility,
        analyticsConsent: analyticsConsent ?? this.analyticsConsent,
      );

  Map<String, dynamic> toJson() => {
        'metric': metric,
        'notifyGroupAlerts': notifyGroupAlerts,
        'notifyCommunity': notifyCommunity,
        'weeklySummary': weeklySummary,
        'shareLocationInGroups': shareLocationInGroups,
        'communityVisibility': communityVisibility.name,
        'analyticsConsent': analyticsConsent,
      };
}

class SettingsController extends Notifier<AppSettings> {
  static const _key = 'settings';

  @override
  AppSettings build() {
    final raw = ref.read(localStoreProvider).rawString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> update(AppSettings Function(AppSettings) fn) async {
    state = fn(state);
    await ref.read(localStoreProvider).setRaw(_key, jsonEncode(state.toJson()));
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
final unitsProvider = Provider<Units>((ref) => ref.watch(settingsProvider).units);

/// CSV of all activities, for the data export in Settings.
String activitiesCsv(Iterable<ActivityRecord> activities) {
  final b = StringBuffer('id,type,title,startedAt,endedAt,distance_m,elevation_gain_m,max_altitude_m,verified,trail_id,district,group_session_id,member_count,separations\n');
  for (final a in activities) {
    String q(Object? v) {
      final s = (v ?? '').toString().replaceAll('"', '""');
      return '"$s"';
    }
    b.writeln([
      q(a.id), q(a.type.name), q(a.title), q(a.startedAt.toIso8601String()), q(a.endedAt.toIso8601String()),
      a.distanceM.toStringAsFixed(1), a.elevationGainM, a.maxAltitudeM, a.verified, q(a.trailId), q(a.district),
      q(a.groupSessionId), a.memberCount, a.separations,
    ].join(','));
  }
  return b.toString();
}
