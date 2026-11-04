import 'package:flutter/material.dart';

/// All activity categories from the product plan. The MVP surfaces
/// [mvpPriority] on the home grid; the rest live behind "View all".
enum ActivityCategory {
  trekking('Trekking', Icons.hiking),
  hiking('Hiking', Icons.directions_walk),
  forestWalk('Forest Walk', Icons.forest),
  mountaineering('Mountaineering', Icons.terrain),
  rockClimbing('Rock Climbing', Icons.landscape),
  camping('Camping', Icons.cabin),
  cycling('Cycling', Icons.pedal_bike),
  mountainBiking('Mountain Biking', Icons.directions_bike),
  trailRunning('Trail Running', Icons.directions_run),
  groupJogging('Group Jogging', Icons.groups),
  kayaking('Kayaking', Icons.kayaking),
  rafting('Rafting', Icons.waves),
  waterfallTrail('Waterfall Trail', Icons.water),
  coracleRide('Coracle Ride', Icons.sailing),
  sightseeing('Sightseeing', Icons.photo_camera_outlined),
  forestStay('Forest Stay', Icons.night_shelter_outlined);

  const ActivityCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  static const List<ActivityCategory> mvpPriority = [
    trekking,
    hiking,
    forestWalk,
    camping,
    waterfallTrail,
  ];

  static ActivityCategory? fromKey(String key) {
    for (final c in values) {
      if (c.name == key) return c;
    }
    return null;
  }
}
