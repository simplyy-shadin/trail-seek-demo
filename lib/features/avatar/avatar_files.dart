import 'dart:io';

/// Image avatars live as PNG files under the app documents directory and
/// are referenced as `img:<file-name>` in `AppUser.avatarId` / `Member.avatarId`.
/// Procedural avatars keep the `v1:` encoding.
class AvatarFiles {
  static Directory? root;

  static bool isImageId(String? id) => id != null && id.startsWith('img:');

  static File? fileFor(String? id) {
    if (!isImageId(id) || root == null) return null;
    return File('${root!.path}/${id!.substring(4)}');
  }

  static String idFor(String fileName) => 'img:$fileName';

  /// Full-body render that pairs with a portrait id: `<stem>-full.png`.
  static File? fullBodyFileFor(String? id) {
    final f = fileFor(id);
    if (f == null) return null;
    final path = f.path;
    return File(path.endsWith('.png') ? '${path.substring(0, path.length - 4)}-full.png' : '$path-full.png');
  }

  static String fullBodyNameFor(String portraitName) =>
      portraitName.endsWith('.png') ? '${portraitName.substring(0, portraitName.length - 4)}-full.png' : '$portraitName-full.png';

  static Future<File> save(String fileName, List<int> bytes) async {
    final dir = root;
    if (dir == null) throw StateError('AvatarFiles.root not set');
    await dir.create(recursive: true);
    final f = File('${dir.path}/$fileName');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }
}
