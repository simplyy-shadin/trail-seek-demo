import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../progress/progress.dart';
import '../profile/profile_tab.dart' show badgeIcon;
import 'explorers.dart';

/// Rank, level, archetype, skills, records, badges, achievements and history
/// for one explorer. Used on every profile, including your own.
class CharacterSheetView extends StatelessWidget {
  const CharacterSheetView({super.key, required this.sheet, this.rank, this.showLevel = true});
  final CharacterSheet sheet;
  final int? rank;

  /// Off on your own profile, whose header already shows level and XP.
  final bool showLevel;

  @override
  Widget build(BuildContext context) {
    final p = sheet.state;
    final s = p.stats;
    final skills = sheet.skills;
    final longest = sheet.longest;
    final highest = sheet.highest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TsCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (rank != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: TsColors.neon, borderRadius: BorderRadius.circular(999)),
                      child: Text('#$rank', style: const TextStyle(fontWeight: FontWeight.w900, color: TsColors.onNeon)),
                    ),
                  if (rank != null) const SizedBox(width: 10),
                  Expanded(child: Text(showLevel ? 'Level ${p.level} · ${p.title}' : 'Rank', style: TsText.h3)),
                  Text(NumberFormat.decimalPattern('en_IN').format(p.totalXp), style: TsText.h3.copyWith(color: TsColors.neon)),
                  const Text(' XP', style: TsText.caption),
                ],
              ),
              const SizedBox(height: 4),
              Text('Style: ${sheet.archetype}', style: TsText.caption.copyWith(color: TsColors.amber, fontWeight: FontWeight.w800)),
              if (showLevel) ...[
                const SizedBox(height: 8),
                XpBar(level: p.level, xpInLevel: p.xpInLevel, xpForLevel: p.xpForLevel, height: 7),
              ],
            ],
          ),
        ),
        const SectionHeader('Skills'),
        for (final k in skills.where((k) => k.count > 0))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(k.icon, color: TsColors.neon, size: 22),
                const SizedBox(width: 10),
                SizedBox(width: 118, child: Text(k.label, style: TsText.bodyStrong)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: k.progress, minHeight: 7, backgroundColor: TsColors.surfaceHigh, valueColor: const AlwaysStoppedAnimation(TsColors.neon)),
                      ),
                      const SizedBox(height: 3),
                      Text('${k.count} done · ${k.km.toStringAsFixed(0)} km', style: TsText.caption),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('Lv ${k.level}', style: TsText.bodyStrong),
              ],
            ),
          ),
        if (skills.every((k) => k.count == 0)) const Text('No outings yet. The first trek starts the climb.', style: TsText.caption),
        const SectionHeader('Records'),
        Row(
          children: [
            Expanded(child: _Record(Icons.landscape, highest == null ? '—' : '${highest.maxAltitudeM} m', 'Highest', highest?.title)),
            const SizedBox(width: 10),
            Expanded(child: _Record(Icons.straighten, longest == null ? '—' : '${(longest.distanceM / 1000).toStringAsFixed(1)} km', 'Longest', longest?.title)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _Record(Icons.hiking, '${s.activityCount}', 'Outings', null)),
            const SizedBox(width: 10),
            Expanded(child: _Record(Icons.route, '${s.totalDistanceKm.toStringAsFixed(0)} km', 'Total', null)),
            const SizedBox(width: 10),
            Expanded(child: _Record(Icons.trending_up, '${NumberFormat.decimalPattern('en_IN').format(s.totalGainM)} m', 'Climbed', null)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _Record(Icons.map_outlined, '${s.districts.length}', 'Districts', null)),
            const SizedBox(width: 10),
            Expanded(child: _Record(Icons.groups, '${s.groupSessions}', 'Group treks', null)),
            const SizedBox(width: 10),
            Expanded(child: _Record(Icons.wb_twilight, '${s.earlyStarts}', 'Dawn starts', null)),
          ],
        ),
        SectionHeader('Badges · ${p.badgeCount} of ${BadgeCatalog.all.length}'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final b in BadgeCatalog.all)
              Opacity(
                opacity: p.hasBadge(b.id) ? 1 : 0.3,
                child: SizedBox(
                  width: 74,
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: TsColors.surfaceHigh, border: Border.all(color: p.hasBadge(b.id) ? TsColors.neon : TsColors.outline, width: 2)),
                        child: Icon(badgeIcon(b.iconKey), color: p.hasBadge(b.id) ? TsColors.neon : TsColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(b.title, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        SectionHeader('Achievements · ${p.achievementCount} of ${AchievementCatalog.all.length}'),
        for (final a in AchievementCatalog.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(p.achievements.containsKey(a.id) ? Icons.emoji_events : Icons.emoji_events_outlined, color: p.achievements.containsKey(a.id) ? TsColors.amber : TsColors.textMuted, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(a.title, style: TsText.bodyStrong)),
                Text('${a.current(s).clamp(0, a.target)} / ${a.target}', style: TsText.caption),
              ],
            ),
          ),
        const SectionHeader('Adventure history'),
        for (final r in sheet.recent.take(25)) _HistoryRow(r, xp: p.xpByActivity[r.id] ?? 0),
        if (sheet.records.length > 25) Padding(padding: const EdgeInsets.only(top: 6), child: Text('+ ${sheet.records.length - 25} earlier adventures', style: TsText.caption)),
      ],
    );
  }
}

class _Record extends StatelessWidget {
  const _Record(this.icon, this.value, this.label, this.where);
  final IconData icon;
  final String value;
  final String label;
  final String? where;
  @override
  Widget build(BuildContext context) {
    return TsCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: TsColors.neon),
          const SizedBox(height: 6),
          Text(value, style: TsText.h3),
          Text(label, style: TsText.caption),
          if (where != null) Text(where!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TsText.caption.copyWith(color: TsColors.textPrimary)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow(this.r, {required this.xp});
  final ActivityRecord r;
  final int xp;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: TsColors.surfaceHigh, borderRadius: BorderRadius.circular(10)),
            child: Icon(switch (r.type) {
              ActivityType.cycling || ActivityType.mountainBiking => Icons.pedal_bike,
              ActivityType.kayaking || ActivityType.rafting => Icons.sailing,
              ActivityType.forestWalk => Icons.forest,
              ActivityType.waterfallTrail => Icons.water,
              ActivityType.hiking || ActivityType.mountaineering => Icons.terrain,
              _ => Icons.hiking,
            }, color: TsColors.neon, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TsText.bodyStrong),
                Text('${DateFormat('d MMM yyyy').format(r.endedAt)} · ${(r.distanceM / 1000).toStringAsFixed(1)} km · ${r.maxAltitudeM} m${r.isGroup ? ' · group of ${r.memberCount}' : ''}', style: TsText.caption),
              ],
            ),
          ),
          Text('+$xp', style: TsText.bodyStrong.copyWith(color: TsColors.neon)),
        ],
      ),
    );
  }
}
