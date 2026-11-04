import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/group_session.dart';
import '../maps/offline_areas.dart';
import '../rope/rope_alerts.dart';
import '../rope/rope_controller.dart';

enum _Status { pending, ok, warn, fail }

class _Check {
  _Check(this.key, this.title, this.icon);
  final String key;
  final String title;
  final IconData icon;
  _Status status = _Status.pending;
  String detail = 'Checking…';
}

class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  late final List<_Check> _checks = [
    _Check('members', 'All members joined', Icons.groups),
    _Check('location', 'Location permission', Icons.location_on),
    _Check('bluetooth', 'Bluetooth', Icons.bluetooth),
    _Check('battery', 'Battery level', Icons.battery_full),
    _Check('maps', 'Offline maps', Icons.map),
    _Check('contacts', 'Emergency contacts', Icons.contact_phone),
    _Check('alerts', 'Alerts & vibration', Icons.notifications_active),
  ];
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAll());
  }

  _Check _c(String key) => _checks.firstWhere((c) => c.key == key);

  Future<void> _runAll() async {
    final s = ref.read(sessionByIdProvider(widget.sessionId));
    if (s == null) return;
    _set('members', s.members.length >= 2 ? _Status.ok : _Status.fail, '${s.members.length} / ${s.plannedSize}');
    await _checkLocation(request: false);
    await _checkBluetooth(request: false);
    await _checkBattery();
    final offline = ref.read(offlineMapsProvider).has(s.adventureId);
    _set('maps', offline ? _Status.ok : _Status.warn, offline ? 'Downloaded' : 'Not downloaded. Tap to download now.');
    final a = await ref.read(adventureRepositoryProvider).byId(s.adventureId);
    final n = a?.emergencyContacts.length ?? 0;
    _set('contacts', n > 0 ? _Status.ok : _Status.warn, n > 0 ? '$n added' : 'None for this adventure');
    final allowed = await RopeAlerts.instance.requestPermission();
    _set('alerts', allowed ? _Status.ok : _Status.warn, allowed ? 'Enabled' : 'Notifications blocked; alerts only on screen');
  }

  void _set(String key, _Status st, String detail) {
    if (!mounted) return;
    setState(() {
      _c(key)
        ..status = st
        ..detail = detail;
    });
  }

  Future<void> _checkLocation({required bool request}) async {
    var status = await Permission.locationWhenInUse.status;
    if (request && !status.isGranted) status = await Permission.locationWhenInUse.request();
    _set('location', status.isGranted ? _Status.ok : _Status.fail, status.isGranted ? 'Enabled' : 'Tap to allow');
  }

  Future<void> _checkBluetooth({required bool request}) async {
    final s = ref.read(sessionByIdProvider(widget.sessionId));
    if (s?.simulated == true) {
      _set('bluetooth', _Status.ok, 'Not needed in demo mode');
      return;
    }
    final perms = Platform.isAndroid
        ? [Permission.bluetoothScan, Permission.bluetoothAdvertise, Permission.bluetoothConnect]
        : [Permission.bluetooth];
    var granted = true;
    for (final p in perms) {
      var st = await p.status;
      if (request && !st.isGranted) st = await p.request();
      granted &= st.isGranted;
    }
    _set('bluetooth', granted ? _Status.ok : _Status.fail, granted ? 'Enabled' : 'Tap to allow');
  }

  Future<void> _checkBattery() async {
    try {
      final level = await Battery().batteryLevel;
      _set('battery', level > 30 ? _Status.ok : (level > 15 ? _Status.warn : _Status.fail),
          level > 30 ? 'Good ( $level% )' : 'Low ( $level% ). Charge before starting.');
    } catch (_) {
      _set('battery', _Status.warn, 'Could not read battery');
    }
  }

  Future<void> _onTap(_Check c) async {
    switch (c.key) {
      case 'location':
        await _checkLocation(request: true);
      case 'bluetooth':
        await _checkBluetooth(request: true);
      case 'battery':
        await _checkBattery();
      case 'maps':
        final s = ref.read(sessionByIdProvider(widget.sessionId));
        final a = s == null ? null : await ref.read(adventureRepositoryProvider).byId(s.adventureId);
        if (a != null) {
          _set('maps', _Status.pending, 'Downloading…');
          await ref.read(offlineMapsProvider.notifier).download(a);
          final ok = ref.read(offlineMapsProvider).has(a.id);
          _set('maps', ok ? _Status.ok : _Status.warn, ok ? 'Downloaded' : 'Download failed; check connection');
        }
      case 'alerts':
        final ok = await RopeAlerts.instance.requestPermission();
        _set('alerts', ok ? _Status.ok : _Status.warn, ok ? 'Enabled' : 'Notifications blocked; alerts only on screen');
      case 'members':
        if (mounted) context.pop();
      default:
        break;
    }
  }

  Future<void> _start() async {
    final s = ref.read(sessionByIdProvider(widget.sessionId));
    if (s == null) return;
    final a = await ref.read(adventureRepositoryProvider).byId(s.adventureId) ??
        (await ref.read(adventureRepositoryProvider).all()).first;
    setState(() => _starting = true);
    final now = DateTime.now();
    final active = await ref.read(groupProvider.notifier).setStatus(s.id, SessionStatus.active, startedAt: now);
    await ref.read(ropeProvider.notifier).start(session: active, adventure: a);
    if (!mounted) return;
    context.pushReplacement('/group/${s.id}/live');
  }

  @override
  Widget build(BuildContext context) {
    final blocking = _checks.any((c) => c.status == _Status.fail);
    return Scaffold(
      appBar: AppBar(title: const Text('Pre-Start Checklist')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          const Text('Make sure everyone is ready', style: TextStyle(color: TsColors.muted)),
          const SizedBox(height: 16),
          for (final c in _checks)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _onTap(c),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: _color(c.status).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                  child: Icon(c.icon, color: _color(c.status), size: 20),
                ),
                title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(c.detail, style: TextStyle(color: _color(c.status), fontSize: 12.5)),
                trailing: Icon(
                  switch (c.status) {
                    _Status.ok => Icons.check_circle,
                    _Status.warn => Icons.error_outline,
                    _Status.fail => Icons.cancel,
                    _Status.pending => Icons.more_horiz,
                  },
                  color: _color(c.status),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Trail Seek is an experimental companion during beta. Keep doing manual headcounts.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: TsColors.muted),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: TsColors.green),
          onPressed: blocking || _starting ? null : _start,
          child: _starting
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(blocking ? 'Fix the red items to start' : 'Start Tracking'),
        ),
      ),
    );
  }

  Color _color(_Status s) => switch (s) {
        _Status.ok => TsColors.green,
        _Status.warn => TsColors.amber,
        _Status.fail => TsColors.red,
        _Status.pending => TsColors.muted,
      };
}
