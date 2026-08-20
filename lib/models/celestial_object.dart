import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum BodyType { planet, sun, moon, star }

class CelestialObject extends Equatable {
  final String id;
  final String name;
  final double ra; // Right Ascension (hours)
  final double dec; // Declination (degrees)
  final BodyType type;
  final Color color;
  final double radius;
  final String? description;

  const CelestialObject({
    required this.id,
    required this.name,
    required this.ra,
    required this.dec,
    required this.type,
    this.color = Colors.white,
    this.radius = 2.0,
    this.description,
  });

  CelestialObject copyWith({
    String? id,
    String? name,
    double? ra,
    double? dec,
    BodyType? type,
    Color? color,
    double? radius,
    String? description,
  }) {
    return CelestialObject(
      id: id ?? this.id,
      name: name ?? this.name,
      ra: ra ?? this.ra,
      dec: dec ?? this.dec,
      type: type ?? this.type,
      color: color ?? this.color,
      radius: radius ?? this.radius,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [id, name, ra, dec, type, color, radius, description];
}

class Constellation extends Equatable {
  final String name;
  final List<CelestialObject> stars;
  final List<List<String>> lines; // List of pairs of star IDs

  const Constellation({
    required this.name,
    required this.stars,
    required this.lines,
  });

  @override
  List<Object?> get props => [name, stars, lines];
}
