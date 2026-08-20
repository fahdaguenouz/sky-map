import 'lib/utils/astronomy_utils.dart';
void main() {
  final coords = AstronomyUtils.getApproximatePlanetsRADec(DateTime.now().toUtc());
  // Estimate location
  final lat = 36.0;
  final lon = 3.0;
  final time = DateTime.now().toUtc();
  
  coords.forEach((name, coord) {
    final altAz = AstronomyUtils.calculateAltAz(coord[0], coord[1], lat, lon, time);
    print('$name: Alt=${altAz.altitude} Az=${altAz.azimuth}');
  });
}
