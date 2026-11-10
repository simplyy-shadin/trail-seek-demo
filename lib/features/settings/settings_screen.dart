import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/group_secret_vault.dart';
import '../../app/backend.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../app/links.dart';
import 'settings_controller.dart';
import '../community/community_controller.dart';
import '../rope/rope_log.dart';

/// Frame 14.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const privacyUrl = 'https://trailseek.app/privacy';
  static const termsUrl = 'https://trailseek.app/terms';
  static const supportEmail = 'support@trailseek.app';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final user = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _Section('Account & Profile', [
            _Tile(Icons.person_outline, 'Username', subtitle: user?.username ?? 'Sign in to edit', onTap: user == null ? null : () => _editUsername(context, ref)),
            _Tile(Icons.mail_outline, 'Email', subtitle: user?.email ?? '—'),
            _Tile(Icons.face_retouching_natural, 'Edit avatar', subtitle: 'From your photo or pick a character', onTap: user == null ? null : () => context.push('/avatar')),
            _Tile(Icons.lock_outline, 'Change password', subtitle: Backend.isCloud ? 'Use “Forgot password” on the login screen' : 'Available once accounts move to the cloud'),
            _Tile(Backend.isCloud ? Icons.cloud_done_outlined : Icons.phone_android, Backend.isCloud ? 'Synced' : 'Saved on this phone', subtitle: Backend.isCloud ? 'Your account and treks sync across phones' : 'Your account and treks are kept on this phone only'),
            if (user != null) _Tile(Icons.logout, 'Sign out', onTap: () => _signOut(context, ref)),
            _Tile(Icons.delete_forever_outlined, 'Delete account & data', danger: true, onTap: () => _deleteAccount(context, ref)),
          ]),
          _Section('Notifications', [
            _Switch(Icons.sensors, 'Group alerts', 'Weak signal, falling behind, "I\'m OK" and "Wait for me". SOS, Stop and separation alarms always sound.', s.notifyGroupAlerts, (v) => n.update((x) => x.copyWith(notifyGroupAlerts: v))),
          ]),
          _Section('Privacy & Security', [
            _Switch(Icons.location_on_outlined, 'Share location in groups', s.shareLocationInGroups ? 'Only during a Digital Rope session, only with your group' : 'Off: your group cannot see you on the map. Alarms still work.', s.shareLocationInGroups, (v) => n.update((x) => x.copyWith(shareLocationInGroups: v))),
            _Tile(Icons.block, 'Blocked users', subtitle: ref.watch(communityProvider).blocked.isEmpty ? 'None' : '${ref.watch(communityProvider).blocked.length} blocked', onTap: () => _blocked(context, ref)),
            _Tile(Icons.download_outlined, 'Export my activities (CSV)', onTap: () => _exportCsv(context, ref)),
            _Tile(Icons.link, 'Export Digital Rope logs (CSV)', subtitle: 'Beta metrics: warnings, separations, reconnects per session', onTap: () => _exportRopeLogs(context, ref)),
            _Tile(Icons.rule, 'Community guidelines', onTap: () => _guidelines(context)),
            _Tile(Icons.privacy_tip_outlined, 'Privacy policy', onTap: () => _open(AppLinks.privacy)),
            _Tile(Icons.description_outlined, 'Terms & conditions', onTap: () => _open(AppLinks.terms)),
          ]),
          _Section('Maps & Units', [
            _Tile(Icons.map_outlined, 'Offline maps', subtitle: 'Download trails for use without signal', onTap: () => context.push('/settings/offline-maps')),
            const _Tile(Icons.straighten, 'Units'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SegmentTabs(
                labels: const ['Metric · km, m', 'Imperial · mi, ft'],
                selected: s.metric ? 0 : 1,
                onChanged: (i) => n.update((x) => x.copyWith(metric: i == 0)),
              ),
            ),
          ]),
          _Section('Help & Support', [
            _Tile(Icons.help_outline, 'FAQ', onTap: () => _faq(context)),
            _Tile(Icons.mail_outlined, 'Contact support', subtitle: supportEmail, onTap: () => _open('mailto:$supportEmail?subject=Trail%20Seek%20support')),
            _Tile(Icons.health_and_safety_outlined, 'Safety notice', onTap: () => _safety(context)),
          ]),
          _Section('Developer & testing', [
            _Tile(Icons.bluetooth_searching, 'Bluetooth diagnostics', subtitle: 'Bench-test the Digital Rope with another phone', onTap: () => context.push('/settings/ble')),
            if (kDebugMode) _Tile(Icons.palette_outlined, 'Design gallery (debug)', onTap: () => context.push('/gallery')),
          ]),
          _Section('About Trail Seek', [
            const _Tile(Icons.info_outline, 'Version', subtitle: '0.5.0 (Thrissur beta)'),
            _Tile(Icons.public, 'Map data © OpenStreetMap contributors', onTap: () => _open('https://www.openstreetmap.org/copyright')),
            _Tile(Icons.system_update_outlined, 'Get the latest version', subtitle: 'trailseek.vercel.app', onTap: () => _open(AppLinks.androidApk)),
            _Tile(Icons.article_outlined, 'Open-source licences', onTap: () => showLicensePage(context: context, applicationName: 'Trail Seek', applicationVersion: '0.5.0')),
          ]),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _editUsername(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController(text: ref.read(authProvider)?.username ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Username'),
        content: TextField(controller: c, autofocus: true, maxLength: 20, decoration: const InputDecoration(prefixText: '@')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim().toLowerCase()), child: const Text('Save')),
        ],
      ),
    );
    if (v == null) return;
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(v)) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('3–20 letters, digits or underscores.')));
      return;
    }
    await ref.read(authProvider.notifier).updateProfile(username: v);
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).signOut();
    if (context.mounted) context.go('/splash');
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('Removes your profile, activities, XP and badges from this phone. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: TsColors.danger, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete everything')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GroupSecretVault.clearAll();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not erase secure group credentials: $e')),
        );
      }
      return; // Never report full deletion while group keys remain.
    }
    await ref.read(localStoreProvider).wipeUserData();
    await ref.read(authProvider.notifier).signOut();
    ref.invalidate(activitiesProvider);
    ref.invalidate(groupProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(savedProvider);
    if (context.mounted) context.go('/splash');
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final csv = activitiesCsv(ref.read(activitiesProvider));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/trailseek-activities.csv');
    await file.writeAsString(csv);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], text: 'Trail Seek activities export'));
  }

  void _blocked(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(communityProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final ids = ref.watch(communityProvider).blocked;
        final names = ctrl.blockedNames();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Blocked users', style: TsText.h2),
                const SizedBox(height: 8),
                if (ids.isEmpty) const Text('Nobody is blocked. Block someone from the ⋯ menu on their post.', style: TsText.caption),
                for (final id in ids)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.block, color: TsColors.danger),
                    title: Text(names[id] ?? id),
                    trailing: TextButton(onPressed: () => ctrl.unblock(id), child: const Text('Unblock')),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _exportRopeLogs(BuildContext context, WidgetRef ref) async {
    final logs = RopeLogStore(ref.read(localStoreProvider)).all();
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Digital Rope sessions recorded yet.')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final summary = File('${dir.path}/trailseek-rope-sessions.csv')..writeAsStringSync(RopeSessionLog.summaryCsv(logs));
    final events = File('${dir.path}/trailseek-rope-events.csv')..writeAsStringSync(RopeSessionLog.eventsCsv(logs));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(summary.path, mimeType: 'text/csv'), XFile(events.path, mimeType: 'text/csv')],
      text: 'Trail Seek Digital Rope logs: ${logs.length} session${logs.length == 1 ? '' : 's'}',
    ));
  }

  void _guidelines(BuildContext context) => _sheet(context, 'Community guidelines', const [
        'Be kind. No harassment, hate or threats.',
        'Post your own photos and words, or credit the source.',
        'Do not share exact locations of nesting sites, rare wildlife or restricted areas.',
        'Safety first: no posts encouraging entry into closed trails or swimming at prohibited falls.',
        'Reports are reviewed; content hidden after three reports stays hidden until checked.',
      ]);

  void _faq(BuildContext context) => _sheet(context, 'FAQ', const [
        'What does "Verified" mean? The app recorded the activity with mostly accurate GPS fixes over at least 500 m. It is not an official certification.',
        'How does Digital Rope work? Phones in a group exchange Bluetooth heartbeats; a member who goes quiet is flagged after a grace period.',
        'Does it work without signal? Yes. Discovery content, recording and Digital Rope all work offline. Download offline maps first.',
        'Why is the battery draining? Continuous GPS costs about 6–8 % per hour. Pause recording on long breaks.',
      ]);

  void _safety(BuildContext context) => _sheet(context, 'Safety notice', const [
        'During beta, Trail Seek is an experimental companion tool, not a primary safety device.',
        'Keep doing manual headcounts and follow your guide and forest department rules.',
        'Bluetooth range varies with terrain, pockets and phone model. Alerts describe trends, never exact distances.',
        'Location is shared only with your group, only during a session.',
      ]);

  void _sheet(BuildContext context, String title, List<String> lines) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(title, style: TsText.h2), const SizedBox(height: 12), BulletList(lines)],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title),
        TsCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(indent: 56),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.title, {this.subtitle, this.onTap, this.danger = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final color = danger ? TsColors.danger : null;
    return ListTile(
      leading: Icon(icon, color: color ?? TsColors.textMuted),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right, color: TsColors.textMuted),
      onTap: onTap,
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch(this.icon, this.title, this.subtitle, this.value, this.onChanged);
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: TsColors.textMuted),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
