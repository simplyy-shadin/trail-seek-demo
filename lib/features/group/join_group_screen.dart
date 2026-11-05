import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key, this.adventureId, this.prefillCode, this.prefillKey});
  final String? adventureId;

  /// From a scanned QR / invite link: pre-filled and auto-submitted.
  final String? prefillCode;
  final String? prefillKey;
  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _code = TextEditingController();
  bool _simulated = false;
  bool _busy = false;
  String? _inviteKey;

  @override
  void initState() {
    super.initState();
    _inviteKey = widget.prefillKey;
    final c = widget.prefillCode?.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (c != null && c.length == 6) {
      _code.text = c;
      WidgetsBinding.instance.addPostFrameCallback((_) => _join(c));
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join([String? code]) async {
    final c = (code ?? _code.text).trim().toUpperCase();
    if (c.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Codes are 6 characters.')));
      return;
    }
    if (!_simulated && (_inviteKey == null ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(_inviteKey!))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('A secure QR invitation is required for real Bluetooth groups. Ask the organizer to share the QR.'),
      ));
      return;
    }
    setState(() => _busy = true);
    final adventure = widget.adventureId == null ? null : await ref.read(adventureRepositoryProvider).byId(widget.adventureId!);
    try {
      final session = await ref.read(groupProvider.notifier).join(
        code: c, adventure: adventure, simulated: _simulated,
        securityKey: _simulated ? null : _inviteKey,
      );
      if (!mounted) return;
      context.pushReplacement('/group/${session.id}/lobby');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot join securely: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final result = await showModalBottomSheet<({String code, String? key})>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Scan the group QR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: MobileScanner(
                  onDetect: (capture) {
                    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
                    if (raw == null) return;
                    final code = extractJoinCode(raw);
                    if (code != null && Navigator.canPop(ctx)) Navigator.pop(ctx, (code: code, key: extractJoinKey(raw)));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      _code.text = result.code;
      _inviteKey = result.key;
      await _join(result.code);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a Group')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text('Enter the team code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Scan the organizer’s private QR to join a real group. A 6-character code alone works only for demos.', style: TextStyle(color: TsColors.muted)),
          const SizedBox(height: 20),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
            style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: 'TRS8A3', counterText: ''),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan QR code')),
          const SizedBox(height: 20),
          SwitchListTile(
            value: _simulated,
            onChanged: (v) => setState(() => _simulated = v),
            activeThumbColor: TsColors.primary,
            tileColor: TsColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TsColors.outline)),
            title: const Text('Try a demo instead (no other phones)'),
            subtitle: Text(_simulated ? 'You will NOT join a real group with this on.' : 'Off = join the real group over Bluetooth.', style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          onPressed: _busy ? null : () => _join(),
          child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Join Group'),
        ),
      ),
    );
  }
}

/// The group code inside a scanned QR or pasted invite: `trailseek://join/FFXZYD`,
/// "… Code: FFXZYD …" or just "FFXZYD". The code must be a whole word, so the
/// letters of "trailseek" are never mistaken for it.
String? extractJoinCode(String raw) {
  final up = raw.toUpperCase();
  final tagged = RegExp(r'(?:JOIN/|CODE:\s*)([A-Z0-9]{6})(?![A-Z0-9])').firstMatch(up);
  if (tagged != null) return tagged.group(1);
  return RegExp(r'(?<![A-Z0-9])([A-Z0-9]{6})(?![A-Z0-9])').firstMatch(up)?.group(1);
}

/// Reads the 256-bit group credential from a private QR/deep link.
/// Never infer a secret from the short six-character discovery code.
String? extractJoinKey(String raw) {
  final m = RegExp(r'(?:[?&]key=)([0-9a-fA-F]{64})(?![0-9a-fA-F])', caseSensitive: false).firstMatch(raw);
  return m?.group(1)?.toLowerCase();
}
