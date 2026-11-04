/// Distance/elevation formatting in the user's preferred system.
class Units {
  const Units({required this.metric});
  final bool metric;

  static const km2mi = 0.621371;
  static const m2ft = 3.28084;

  String distanceKm(double km, {int decimals = 1}) => metric ? '${_n(km, decimals)} km' : '${_n(km * km2mi, decimals)} mi';
  String distanceM(double m, {int decimals = 1}) => distanceKm(m / 1000, decimals: decimals);
  String elevationM(num m) => metric ? '${m.round()} m' : '${(m * m2ft).round()} ft';
  String get paceUnit => metric ? '/km' : '/mi';

  /// Seconds per unit distance → "m:ss".
  String pace(Duration moving, double distanceM) {
    if (distanceM < 50) return '—';
    final perUnit = moving.inSeconds / (metric ? distanceM / 1000 : distanceM / 1000 * km2mi);
    final m = perUnit ~/ 60;
    final s = (perUnit % 60).round().toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String _n(double v, int d) => v == v.roundToDouble() && d <= 1 ? v.toInt().toString() : v.toStringAsFixed(d);
}
