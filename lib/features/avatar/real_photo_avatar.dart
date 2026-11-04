import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../app/backend.dart';
import '../../app/providers.dart';
import 'avatar_files.dart';

/// Use the person's real photo as their avatar: square-cropped, 512 px JPEG.
/// Local builds keep it on the phone; cloud builds upload it so other
/// explorers see the same face.
Future<bool> pickRealPhotoAvatar(BuildContext context, WidgetRef ref, ImageSource source) async {
  final x = await ImagePicker().pickImage(source: source, maxWidth: 1400, maxHeight: 1400, imageQuality: 90, preferredCameraDevice: CameraDevice.front);
  if (x == null) return false;
  final decoded = img.decodeImage(await File(x.path).readAsBytes());
  if (decoded == null) return false;
  final oriented = img.bakeOrientation(decoded);
  final side = oriented.width < oriented.height ? oriented.width : oriented.height;
  // Slightly above centre: faces sit in the upper half of most selfies.
  final top = ((oriented.height - side) * 0.35).round();
  final square = img.copyResize(img.copyCrop(oriented, x: (oriented.width - side) ~/ 2, y: top, width: side, height: side), width: 512, height: 512, interpolation: img.Interpolation.average);
  final bytes = img.encodeJpg(square, quality: 85);
  final name = '${const Uuid().v4()}.jpg';
  String avatarId;
  if (Backend.isCloud && ref.read(authProvider) != null) {
    final key = '${ref.read(authProvider)!.id}/avatar-$name';
    await Backend.client.storage.from('post-photos').uploadBinary(key, bytes);
    avatarId = Backend.client.storage.from('post-photos').getPublicUrl(key);
  } else {
    await AvatarFiles.save(name, bytes);
    avatarId = AvatarFiles.idFor(name);
  }
  await ref.read(authProvider.notifier).updateProfile(avatarId: avatarId);
  return true;
}
