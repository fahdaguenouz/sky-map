import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:flutter/material.dart';

import 'sky_map_event.dart';
import 'sky_map_state.dart';
import '../models/celestial_object.dart';
import '../utils/astronomy_utils.dart';

class SkyMapBloc extends Bloc<SkyMapEvent, SkyMapState> {
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _magnetometerSubscription;
  Timer? _updateTimer;

  // Raw sensor data (no low-pass filter here — we filter in place)
  Vector3 _gravity = Vector3(0, 0, -9.8);
  Vector3 _magnetometer = Vector3(1, 0, 0);

  // Because we are now updating at 60Hz (16ms), the filter applies much more frequently.
  // We lower the alpha values to give a ~100-200ms smoothing window, eliminating jitter
  // while remaining highly responsive compared to the old 5Hz update rate.
  static const double _gravAlpha = 0.15; 
  static const double _magAlpha = 0.08;

  // Publicly accessible pitch/yaw for the painter to read WITHOUT going through BLoC
  // This avoids triggering a full Flutter rebuild every 33ms.
  double pitch = 0.0;
  double yaw = 0.0;

  SkyMapBloc() : super(const SkyMapState()) {
    on<InitializeSkyMap>(_onInitialize);
    on<UpdateOrientation>(_onUpdateOrientation);
  }

  Future<void> _onInitialize(InitializeSkyMap event, Emitter<SkyMapState> emit) async {
    try {
      // 1. Get Location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        emit(state.copyWith(error: "Location services are disabled.", isLoading: false));
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(state.copyWith(error: "Location permissions are denied", isLoading: false));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        emit(state.copyWith(error: "Location permissions permanently denied. Please enable in Settings.", isLoading: false));
        return;
      }
      Position position = await Geolocator.getCurrentPosition();

      // 2. Load Constellations
      String jsonStr = await rootBundle.loadString('assets/constellations.json');
      Map<String, dynamic> data = jsonDecode(jsonStr);
      List<Constellation> constellations = [];
      for (var constell in data['constellations']) {
        List<CelestialObject> stars = [];
        for (var star in constell['stars']) {
          stars.add(CelestialObject(
            id: star['id'],
            name: star['id'],
            ra: star['ra'].toDouble(),
            dec: star['dec'].toDouble(),
            type: BodyType.star,
          ));
        }
        List<List<String>> lines = [];
        for (var line in constell['lines']) {
          lines.add([line[0], line[1]]);
        }
        constellations.add(Constellation(name: constell['name'], stars: stars, lines: lines));
      }

      // 3. Create Planets using full Keplerian orbital mechanics
      final Map<String, Color> planetColors = {
        'Sun': const Color(0xFFFFE566),
        'Moon': const Color(0xFFDDDDCC),
        'Mercury': const Color(0xFFAAAAAA),
        'Venus': const Color(0xFFFFCC77),
        'Mars': const Color(0xFFDD4422),
        'Jupiter': const Color(0xFFD4A76A),
        'Saturn': const Color(0xFFCCAA55),
        'Uranus': const Color(0xFF88DDEE),
        'Neptune': const Color(0xFF3366FF),
      };

      List<CelestialObject> objects = [];
      var planetCoords = AstronomyUtils.getApproximatePlanetsRADec(DateTime.now().toUtc());
      planetCoords.forEach((name, coords) {
        objects.add(CelestialObject(
          id: name,
          name: name,
          ra: coords[0],
          dec: coords[1],
          type: name == 'Sun'
              ? BodyType.sun
              : (name == 'Moon' ? BodyType.moon : BodyType.planet),
          color: planetColors[name] ?? Colors.white,
          radius: name == 'Sun' || name == 'Moon' ? 9.0 : 5.0,
        ));
      });

      // Add Deep Sky Objects (DSOs) and Famous Stars
      objects.addAll([
        const CelestialObject(id: 'M31', name: 'Andromeda Galaxy', ra: 0.7123, dec: 41.269, type: BodyType.planet, color: Color(0xFF99BBFF), radius: 7.0),
        const CelestialObject(id: 'M42', name: 'Orion Nebula', ra: 5.58814, dec: -5.39111, type: BodyType.planet, color: Color(0xFFFF88DD), radius: 7.0),
        const CelestialObject(id: 'M45', name: 'Pleiades', ra: 3.7912, dec: 24.116, type: BodyType.planet, color: Color(0xFF88AAFF), radius: 6.5),
        const CelestialObject(id: 'Sirius', name: 'Sirius (Star)', ra: 6.7525, dec: -16.7161, type: BodyType.planet, color: Color(0xFFDDFFFF), radius: 5.0),
        const CelestialObject(id: 'Betelgeuse', name: 'Betelgeuse (Star)', ra: 5.9195, dec: 7.4070, type: BodyType.planet, color: Color(0xFFFFBBAA), radius: 5.0),
        const CelestialObject(id: 'Polaris', name: 'Polaris (North Star)', ra: 2.5303, dec: 89.2641, type: BodyType.planet, color: Color(0xFFFFFFAA), radius: 5.0),
      ]);

      emit(state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        constellations: constellations,
        objects: objects,
        isLoading: false,
      ));

      // 4. Start sensors — request 60Hz update rate from Android
      _accelerometerSubscription = accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 16)).listen((event) {
        _gravity = Vector3(
          _lerp(_gravity.x, event.x, _gravAlpha),
          _lerp(_gravity.y, event.y, _gravAlpha),
          _lerp(_gravity.z, event.z, _gravAlpha),
        );
      });
      _magnetometerSubscription = magnetometerEventStream(samplingPeriod: const Duration(milliseconds: 16)).listen((event) {
        _magnetometer = Vector3(
          _lerp(_magnetometer.x, event.x, _magAlpha),
          _lerp(_magnetometer.y, event.y, _magAlpha),
          _lerp(_magnetometer.z, event.z, _magAlpha),
        );
      });

      // 5. Timer at ~60fps to update orientation (painter reads pitch/yaw directly)
      //    We only emit a BLoC event every 5 frames (300ms) to update the HUD display.
      int frameCount = 0;
      _updateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        _calculateOrientation();
        frameCount++;
        if (frameCount % 18 == 0) {
          // Emit to BLoC every ~300ms (just for HUD compass numbers)
          add(UpdateOrientation(pitch, yaw, 0.0));
        }
      });
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _calculateOrientation() {
    // Tilt-Compensated Compass via Rotation Matrix
    // Android sensor frame: X=right, Y=up (toward top of phone), Z=toward user (out of screen)
    //
    // gravity vector points "down" in sensor frame (i.e., toward Earth center)
    final Vector3 grav = _gravity.normalized(); // world Up direction in sensor frame
    final Vector3 mag = _magnetometer.normalized();

    // CORRECT tilt-compensated compass (Android standard algorithm):
    // East = mag × grav  (NOT grav × mag — that gives West!)
    final Vector3 east = mag.cross(grav);
    if (east.length < 1e-6) return; // degenerate: phone pointing at magnetic pole
    final Vector3 eastN = east.normalized();

    // North = grav × East  (horizontal, pointing geographic north)
    final Vector3 northN = grav.cross(eastN).normalized();

    // Camera (back) points in the -Z sensor direction.
    // Its altitude above horizon = dot(camera, world_up) = dot((0,0,-1), grav) = -grav.z
    // When phone flat face-down (camera toward earth): grav.z=+1 → alt = -90° ✓
    // When phone tilted back looking at sky: grav.z<0 → alt > 0° ✓
    final double altRad = asin((-grav.z).clamp(-1.0, 1.0));

    // Azimuth: atan2(East component, North component) of camera direction
    final double northComp = -northN.z;
    final double eastComp = -eastN.z;
    final double azimRad = atan2(eastComp, northComp);

    // Store directly (painter reads these each frame without triggering rebuild)
    pitch = altRad;
    yaw = azimRad;
  }

  void _onUpdateOrientation(UpdateOrientation event, Emitter<SkyMapState> emit) {
    // Only used to update the HUD display — not for painting (painter reads pitch/yaw directly)
    emit(state.copyWith(
      pitch: event.pitch,
      yaw: event.yaw,
      roll: event.roll,
    ));
  }

  @override
  Future<void> close() {
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _updateTimer?.cancel();
    return super.close();
  }
}
