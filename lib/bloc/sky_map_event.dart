import 'package:equatable/equatable.dart';

abstract class SkyMapEvent extends Equatable {
  const SkyMapEvent();

  @override
  List<Object> get props => [];
}

class InitializeSkyMap extends SkyMapEvent {}

class UpdateOrientation extends SkyMapEvent {
  final double pitch;
  final double yaw;
  final double roll;

  const UpdateOrientation(this.pitch, this.yaw, this.roll);

  @override
  List<Object> get props => [pitch, yaw, roll];
}
