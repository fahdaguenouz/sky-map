import 'dart:math';
import 'package:flutter/material.dart';
import '../bloc/sky_map_bloc.dart';
import '../models/celestial_object.dart';
import '../utils/astronomy_utils.dart';
import '../bloc/sky_map_state.dart';

class SkyPainter extends CustomPainter {
  final SkyMapState state;
  final SkyMapBloc bloc; // Direct reference to read pitch/yaw without BLoC rebuild

  static List<_PaintedObject> paintedObjects = [];

  // Field of view: ~70 degrees
  static const double _fovRad = 1.22; // ~70°

  SkyPainter(this.state, this.bloc, Listenable repaintNotifier) : super(repaint: repaintNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    paintedObjects.clear();

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double scale = size.width / _fovRad;

    // Read sensor values directly from bloc (no rebuild needed)
    final double pitchRad = bloc.pitch;
    final double yawRad = bloc.yaw;

    // --- Background gradient ---
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [Color(0xFF0B1130), Color(0xFF030608)],
        ).createShader(bgRect),
    );

    // --- Ambient background stars (fixed, seeded) ---
    _drawAmbientStars(canvas, size);

    if (state.isLoading) return;

    final DateTime now = DateTime.now().toUtc();

    // Horizon check: only draw things within ±90° of where we're pointing
    // Pre-compute projection helper
    Offset? project(double ra, double dec) {
      final AltAz pos = AstronomyUtils.calculateAltAz(
          ra, dec, state.latitude, state.longitude, now);
      return _projectAltAz(pos.altitude, pos.azimuth, pitchRad, yawRad, cx, cy, scale);
    }

    // --- Constellation lines ---
    _drawConstellations(canvas, cx, cy, scale, pitchRad, yawRad, now);

    // --- Solar system objects ---
    for (final obj in state.objects) {
      final offset = project(obj.ra, obj.dec);
      if (offset == null) continue;

      switch (obj.type) {
        case BodyType.sun:
          _drawSun(canvas, offset, obj.radius);
          _drawLabel(canvas, obj.name, offset, obj.radius, const Color(0xFFFFE566));
          break;
        case BodyType.moon:
          _drawMoon(canvas, offset, obj.radius);
          _drawLabel(canvas, obj.name, offset, obj.radius, const Color(0xFFDDDDCC));
          break;
        case BodyType.planet:
          _drawPlanet(canvas, offset, obj);
          _drawLabel(canvas, obj.name, offset, obj.radius, obj.color);
          break;
        case BodyType.star:
          canvas.drawCircle(offset, obj.radius, Paint()..color = obj.color);
          break;
      }

      paintedObjects.add(_PaintedObject(obj,
          Rect.fromCircle(center: offset, radius: obj.radius + 22)));
    }

    // --- Crosshair ---
    _drawCrosshair(canvas, cx, cy);
  }

  /// Project alt/az (degrees) to screen coordinates. Returns null if off-screen.
  Offset? _projectAltAz(double altDeg, double azDeg, double pitchRad, double yawRad,
      double cx, double cy, double scale) {
    // Skip objects well below the horizon
    if (altDeg < -10) return null;

    final double altR = altDeg * pi / 180.0;
    final double azR = azDeg * pi / 180.0;

    double dAz = azR - yawRad;
    // Wrap to [-π, π]
    while (dAz > pi) dAz -= 2 * pi;
    while (dAz < -pi) dAz += 2 * pi;

    final double dAlt = altR - pitchRad;

    final double dx = dAz * scale;
    final double dy = -dAlt * scale; // screen Y increases downward

    // Cull if too far off-screen
    if (dx < -cx * 1.8 || dx > cx * 1.8 || dy < -cy * 1.8 || dy > cy * 1.8) return null;

    return Offset(cx + dx, cy + dy);
  }

  void _drawAmbientStars(Canvas canvas, Size size) {
    final rng = Random(1337);
    for (int i = 0; i < 250; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.0 + 0.3;
      final opacity = rng.nextDouble() * 0.55 + 0.25;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withOpacity(opacity));
    }
  }

  void _drawConstellations(Canvas canvas, double cx, double cy, double scale,
      double pitchRad, double yawRad, DateTime now) {
    // Line paint — no blur for performance, use a faint color instead
    final linePaint = Paint()
      ..color = const Color(0x446688CC)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    final starCorePaint = Paint()..color = const Color(0xFFCCDDFF);

    for (final constell in state.constellations) {
      final Map<String, Offset?> positions = {};

      for (final star in constell.stars) {
        final AltAz pos = AstronomyUtils.calculateAltAz(
            star.ra, star.dec, state.latitude, state.longitude, now);
        positions[star.id] =
            _projectAltAz(pos.altitude, pos.azimuth, pitchRad, yawRad, cx, cy, scale);
      }

      // Lines
      for (final line in constell.lines) {
        final a = positions[line[0]];
        final b = positions[line[1]];
        if (a != null && b != null) canvas.drawLine(a, b, linePaint);
      }

      // Stars
      for (final pos in positions.values) {
        if (pos == null) continue;
        // Small outer glow (cheap: just a slightly larger semi-transparent circle)
        canvas.drawCircle(pos, 3.5, Paint()..color = const Color(0x226688CC));
        canvas.drawCircle(pos, 1.6, starCorePaint);
      }

      // Constellation name near the center of visible stars
      final visible = positions.values.whereType<Offset>().toList();
      if (visible.length >= 2) {
        final c = visible.reduce((a, b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2));
        _drawSmallLabel(canvas, constell.name.toUpperCase(), c + const Offset(0, 12));
      }
    }
  }

  void _drawSun(Canvas canvas, Offset c, double r) {
    // Corona (cheap gradient via concentric circles)
    canvas.drawCircle(c, r * 3.2, Paint()..color = const Color(0x0CFFE566));
    canvas.drawCircle(c, r * 2.2, Paint()..color = const Color(0x22FFD700));
    canvas.drawCircle(c, r * 1.5, Paint()..color = const Color(0x55FFD700));
    // Core
    canvas.drawCircle(c, r, Paint()
      ..shader = RadialGradient(colors: [Colors.white, const Color(0xFFFFE566), const Color(0xFFFFAA00)])
          .createShader(Rect.fromCircle(center: c, radius: r)));
  }

  void _drawMoon(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r * 1.8, Paint()..color = const Color(0x18DDDDCC));
    canvas.drawCircle(c, r, Paint()
      ..shader = RadialGradient(
              colors: [const Color(0xFFEEEEDD), const Color(0xFFBBBBAA)])
          .createShader(Rect.fromCircle(center: c, radius: r)));
  }

  void _drawPlanet(Canvas canvas, Offset c, CelestialObject obj) {
    final Color col = obj.color;
    final double r = obj.radius;
    // Cheap glow: two concentric semi-transparent circles
    canvas.drawCircle(c, r * 2.2, Paint()..color = col.withOpacity(0.12));
    canvas.drawCircle(c, r * 1.5, Paint()..color = col.withOpacity(0.30));
    // Core
    canvas.drawCircle(c, r, Paint()
      ..shader = RadialGradient(colors: [col, Color.lerp(col, Colors.black, 0.5)!])
          .createShader(Rect.fromCircle(center: c, radius: r)));
    // Specular
    canvas.drawCircle(
        c + Offset(-r * 0.28, -r * 0.28), r * 0.28, Paint()..color = Colors.white.withOpacity(0.22));
  }

  void _drawCrosshair(Canvas canvas, double cx, double cy) {
    final p = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 0.9;
    const double gap = 16;
    const double len = 26;

    canvas.drawLine(Offset(cx - gap - len, cy), Offset(cx - gap, cy), p);
    canvas.drawLine(Offset(cx + gap, cy), Offset(cx + gap + len, cy), p);
    canvas.drawLine(Offset(cx, cy - gap - len), Offset(cx, cy - gap), p);
    canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + gap + len), p);

    canvas.drawCircle(Offset(cx, cy), 2.0, Paint()..color = const Color(0x88FFFFFF));
    canvas.drawCircle(Offset(cx, cy), gap,
        Paint()
          ..color = const Color(0x22FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7);
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, double radius, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withOpacity(0.9),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          shadows: const [Shadow(color: Colors.black, blurRadius: 6, offset: Offset(1, 1))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos + Offset(radius + 5, -6));
  }

  void _drawSmallLabel(Canvas canvas, String text, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0x886688BB),
          fontSize: 8,
          letterSpacing: 1.2,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, 0));
  }

  static void handleTap(Offset tapPosition, Function(CelestialObject) onTapped) {
    for (final obj in paintedObjects) {
      if (obj.rect.contains(tapPosition)) {
        onTapped(obj.object);
        return;
      }
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) =>
      old.bloc.pitch != bloc.pitch ||
      old.bloc.yaw != bloc.yaw ||
      old.state != state;
}

class _PaintedObject {
  final CelestialObject object;
  final Rect rect;
  _PaintedObject(this.object, this.rect);
}
