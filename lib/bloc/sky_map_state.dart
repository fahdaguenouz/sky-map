import 'package:equatable/equatable.dart';
import '../models/celestial_object.dart';

class SkyMapState extends Equatable {
  final double pitch;
  final double yaw;
  final double roll;
  final double latitude;
  final double longitude;
  final List<CelestialObject> objects;
  final List<Constellation> constellations;
  final bool isLoading;
  final String? error;

  const SkyMapState({
    this.pitch = 0.0,
    this.yaw = 0.0,
    this.roll = 0.0,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.objects = const [],
    this.constellations = const [],
    this.isLoading = true,
    this.error,
  });

  SkyMapState copyWith({
    double? pitch,
    double? yaw,
    double? roll,
    double? latitude,
    double? longitude,
    List<CelestialObject>? objects,
    List<Constellation>? constellations,
    bool? isLoading,
    String? error,
  }) {
    return SkyMapState(
      pitch: pitch ?? this.pitch,
      yaw: yaw ?? this.yaw,
      roll: roll ?? this.roll,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      objects: objects ?? this.objects,
      constellations: constellations ?? this.constellations,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [pitch, yaw, roll, latitude, longitude, objects, constellations, isLoading, error];
}
