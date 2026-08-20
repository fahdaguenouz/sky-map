import 'lib/utils/astronomy_utils.dart';
void main() {
  final coords = AstronomyUtils.getApproximatePlanetsRADec(DateTime.now().toUtc());
  coords.forEach((name, coord) {
    print('$name: RA=${coord[0]} Dec=${coord[1]}');
  });
}
