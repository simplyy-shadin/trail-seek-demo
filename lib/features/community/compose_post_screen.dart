import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/activity_record.dart';
import 'community_controller.dart';

/// Compose: text + up to 4 photos + optional place + optional activity.
class ComposePostScreen extends ConsumerStatefulWidget {
  const ComposePostScreen({super.key});
  @override
  ConsumerState<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends ConsumerState<ComposePostScreen> {
  final _text = TextEditingController();
  final _place = TextEditingController();
  final List<String> _photos = [];
  ActivityRecord? _activity;
  bool _busy = false;

  static const maxPhotos = 4;
  static const maxBytes = 400 * 1024;

  @override
  void dispose() {
    _text.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_photos.length >= maxPhotos) return;
    final picker = ImagePicker();
    // Picker re-encodes to ≤1600 px at 80 % quality; that lands under ~400 KB for photos.
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    if (x == null) return;
    final bytes = await x.length();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/posts/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.parent.create(recursive: true);
    await File(x.path).copy(file.path);
    if (!mounted) return;
    if (bytes > maxBytes * 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That photo is large; it will be compressed further when uploads arrive.')));
    }
    setState(() => _photos.add(file.path));
  }

  Future<void> _pickActivity() async {
    final list = ref.read(activitiesProvider);
    final picked = await showModalBottomSheet<ActivityRecord>(
      context: context,
      builder: (ctx) => SafeArea(
        child: list.isEmpty
            ? const Padding(padding: EdgeInsets.all(24), child: Text('No activities to attach yet.', style: TsText.caption))
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final a in list.take(20))
                    ListTile(
                      leading: const Icon(Icons.route, color: TsColors.neon),
                      title: Text(a.title),
                      subtitle: Text('${a.distanceKm.toStringAsFixed(1)} km · ${a.elevationGainM} m'),
                      onTap: () => Navigator.pop(ctx, a),
                    ),
                ],
              ),
      ),
    );
    if (picked != null) setState(() => _activity = picked);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final p = await ref.read(communityProvider.notifier).post(
          text: _text.text,
          photoPaths: _photos,
          placeName: _place.text.trim().isEmpty ? null : _place.text.trim(),
          activityId: _activity?.id,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write something or add a photo first.')));
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          TextField(
            controller: _text,
            maxLines: 6,
            minLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'What did the trail give you today? Use #hashtags.'),
          ),
          const SizedBox(height: 8),
          TextField(controller: _place, decoration: const InputDecoration(hintText: 'Place (optional)', prefixIcon: Icon(Icons.place_outlined))),
          const SectionHeader('Photos'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in _photos)
                Stack(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(p), width: 84, height: 84, fit: BoxFit.cover)),
                    Positioned(right: 2, top: 2, child: GestureDetector(onTap: () => setState(() => _photos.remove(p)), child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14)))),
                  ],
                ),
              if (_photos.length < maxPhotos)
                GestureDetector(
                  onTap: _pick,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(color: TsColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: TsColors.outline)),
                    child: const Icon(Icons.add_a_photo_outlined, color: TsColors.textMuted),
                  ),
                ),
            ],
          ),
          const SectionHeader('Attach activity'),
          TsCard(
            onTap: _pickActivity,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.route, color: TsColors.neon),
                const SizedBox(width: 12),
                Expanded(child: Text(_activity?.title ?? 'None', style: TsText.bodyStrong)),
                if (_activity != null) IconButton(onPressed: () => setState(() => _activity = null), icon: const Icon(Icons.close, size: 18)) else const Icon(Icons.chevron_right, color: TsColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Do not share exact locations of nesting sites, rare wildlife or restricted areas.', style: TsText.caption),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: NeonButton(label: 'Post', icon: Icons.send, loading: _busy, onPressed: _submit),
      ),
    );
  }
}
