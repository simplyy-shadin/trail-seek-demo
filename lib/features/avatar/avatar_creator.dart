import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import 'real_photo_avatar.dart';

class AvatarCharacter {
  const AvatarCharacter(this.key, this.name);
  final String key;
  final String name;
}

/// Trekker characters, all in the same summit scene and kit; only the person
/// changes. Rendered locally from tools/avatars/reference.png and bundled as
/// `assets/images/characters/<key>.jpg` (full body) and `<key>_face.jpg`.
/// Ids look like `char:arav` (older `char:arav:<tier>` ids still resolve).
class CharacterCatalog {
  static const characters = [
    AvatarCharacter('arav', 'Arav'),
    AvatarCharacter('kiran', 'Kiran'),
    AvatarCharacter('rohan', 'Rohan'),
    AvatarCharacter('faisal', 'Faisal'),
    AvatarCharacter('joseph', 'Joseph'),
    AvatarCharacter('dev', 'Dev'),
    AvatarCharacter('ananya', 'Ananya'),
    AvatarCharacter('meera', 'Meera'),
    AvatarCharacter('sara', 'Sara'),
    AvatarCharacter('ayesha', 'Ayesha'),
    AvatarCharacter('lakshmi', 'Lakshmi'),
    AvatarCharacter('nila', 'Nila'),
  ];

  static String full(String c) => 'assets/images/characters/$c.jpg';
  static String face(String c) => 'assets/images/characters/${c}_face.jpg';
  static String id(String c) => 'char:$c';

  static String? parse(String? id) {
    if (id == null || !id.startsWith('char:')) return null;
    final p = id.split(':');
    if (p.length < 2 || p.length > 3 || !characters.any((c) => c.key == p[1])) return null;
    return p[1];
  }
}

/// Screen 3 of the mockup: full-body character, thumbnails on the right, arrows.
class AvatarCreatorScreen extends ConsumerStatefulWidget {
  const AvatarCreatorScreen({super.key});
  @override
  ConsumerState<AvatarCreatorScreen> createState() => _AvatarCreatorScreenState();
}

class _AvatarCreatorScreenState extends ConsumerState<AvatarCreatorScreen> {
  late int _index;
  bool _grid = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cur = CharacterCatalog.parse(ref.read(authProvider)?.avatarId);
    _index = cur == null ? 0 : CharacterCatalog.characters.indexWhere((c) => c.key == cur);
  }

  String get _char => CharacterCatalog.characters[_index].key;

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(authProvider.notifier).updateProfile(avatarId: CharacterCatalog.id(_char));
    if (!mounted) return;
    setState(() => _saving = false);
    context.go('/avatar/done');
  }

  Future<void> _photo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a selfie'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final ok = await pickRealPhotoAvatar(context, ref, source);
      if (ok && mounted) context.go('/avatar/done');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not use that photo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => _grid ? _all(context) : _choose(context);

  Widget _choose(BuildContext context) {
    final chars = CharacterCatalog.characters;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Image.asset(CharacterCatalog.full(_char), key: ValueKey(_char), fit: BoxFit.cover, alignment: Alignment.center),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.2, 0.75, 1], colors: [Color(0xCC000000), Colors.transparent, Colors.transparent, Color(0xEE000000)])),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                  child: Row(children: [
                    if (context.canPop()) const BackButton(),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Choose Your Avatar', style: TsText.h1)),
                    IconButton(tooltip: 'All avatars', onPressed: () => setState(() => _grid = true), icon: const Icon(Icons.grid_view)),
                  ]),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Spacer(),
                      // Thumbnail column, like the mockup.
                      Container(
                        width: 76,
                        margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(16)),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: chars.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => setState(() => _index = i),
                            child: Container(
                              height: 64,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: i == _index ? TsColors.neon : Colors.white24, width: i == _index ? 2.5 : 1)),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(CharacterCatalog.face(chars[i].key), fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Text(chars[_index].name, style: TsText.h3),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(children: [
                    RoundIconButton(icon: Icons.chevron_left, onTap: () => setState(() => _index = (_index - 1 + chars.length) % chars.length)),
                    const SizedBox(width: 12),
                    Expanded(child: NeonButton(label: 'Save avatar', loading: _saving, onPressed: _saving ? null : _save)),
                    const SizedBox(width: 12),
                    RoundIconButton(icon: Icons.chevron_right, onTap: () => setState(() => _index = (_index + 1) % chars.length)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _all(BuildContext context) {
    final chars = CharacterCatalog.characters;
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => setState(() => _grid = false))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 2 / 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (var i = 0; i < chars.length; i++)
                GestureDetector(
                  onTap: () => setState(() {
                    _index = i;
                    _grid = false;
                  }),
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: i == _index ? TsColors.neon : TsColors.outline, width: i == _index ? 2.5 : 1)),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(CharacterCatalog.full(chars[i].key), fit: BoxFit.cover),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TsCard(
            onTap: _photo,
            padding: const EdgeInsets.all(14),
            child: const Row(children: [
              Icon(Icons.face, color: TsColors.neon),
              SizedBox(width: 12),
              Expanded(child: Text('Use my real photo instead', style: TsText.bodyStrong)),
              Icon(Icons.chevron_right, color: TsColors.textMuted),
            ]),
          ),
        ],
      ),
    );
  }
}
