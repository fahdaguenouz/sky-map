import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/sky_map_bloc.dart';
import '../bloc/sky_map_event.dart';
import '../bloc/sky_map_state.dart';
import '../data/api_repository.dart';
import '../models/celestial_object.dart';
import 'sky_painter.dart';

class SkyMapPage extends StatefulWidget {
  const SkyMapPage({super.key});

  @override
  State<SkyMapPage> createState() => _SkyMapPageState();
}

class _SkyMapPageState extends State<SkyMapPage> with SingleTickerProviderStateMixin {
  final ApiRepository apiRepo = ApiRepository();
  late SkyMapBloc _bloc;
  Ticker? _ticker;
  final ValueNotifier<int> _repaintNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _bloc = SkyMapBloc()..add(InitializeSkyMap());

    // Use a Ticker to drive repaints at display refresh rate (~60fps)
    _ticker = createTicker((elapsed) {
      _repaintNotifier.value++;
    });
    _ticker!.start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaintNotifier.dispose();
    _bloc.close();
    super.dispose();
  }

  String _azToCompass(double radians) {
    double deg = (radians * 180 / pi) % 360;
    if (deg < 0) deg += 360;
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[(deg / 45).round() % 8];
  }

  void _showObjectInfo(BuildContext context, CelestialObject obj) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildInfoSheet(obj.name, null),
    );

    String info = await apiRepo.getBodyDescription(obj.name);

    if (context.mounted) {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _buildInfoSheet(obj.name, info),
      );
    }
  }

  Widget _buildInfoSheet(String name, String? info) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1320),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: const [
          BoxShadow(color: Color(0x441A3A6A), blurRadius: 32, spreadRadius: 4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Color(0xFF4A9EFF), shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(name.toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF4A9EFF), fontSize: 13,
                    fontWeight: FontWeight.w600, letterSpacing: 3)),
          ]),
          const SizedBox(height: 16),
          if (info == null)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFF4A9EFF), strokeWidth: 2))
          else
            Text(info,
                style: const TextStyle(color: Color(0xFFB0C4DE), fontSize: 14, height: 1.6)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<SkyMapBloc, SkyMapState>(
        builder: (context, state) {
          if (state.isLoading) return _buildLoadingScreen();
          if (state.error != null) return _buildErrorScreen(state.error!);

          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                // Main sky view — repaints via Ticker, NOT via BLoC state changes
                GestureDetector(
                  onTapUp: (details) {
                    SkyPainter.handleTap(details.localPosition, (obj) {
                      if (obj.type != BodyType.star) {
                        _showObjectInfo(context, obj);
                      }
                    });
                  },
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: SkyPainter(state, _bloc, _repaintNotifier),
                  ),
                ),

                // Top HUD
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: _buildTopHUD(state),
                ),

                // Bottom hint
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _buildBottomHUD(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFF030608),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.blur_on_rounded, color: Color(0xFF4A9EFF), size: 52),
            SizedBox(height: 20),
            Text('INITIALIZING',
                style: TextStyle(
                    color: Color(0xFF4A9EFF), fontSize: 12,
                    letterSpacing: 5, fontWeight: FontWeight.w300)),
            SizedBox(height: 8),
            Text('Calibrating sensors & locating stars...',
                style: TextStyle(color: Color(0xFF3A5A8A), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: const Color(0xFF030608),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4A4A), size: 48),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFF8080), fontSize: 14)),
          ]),
        ),
      ),
    );
  }

  Widget _buildTopHUD(SkyMapState state) {
    // Read live pitch/yaw from bloc directly (updated every ~300ms via BLoC state)
    double azDeg = (_bloc.yaw * 180 / pi) % 360;
    if (azDeg < 0) azDeg += 360;
    double altDeg = _bloc.pitch * 180 / pi;
    String compass = _azToCompass(_bloc.yaw);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.72), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 20),
      child: Row(
        children: [
          _hudChip(icon: Icons.explore_rounded, label: compass,
              value: '${azDeg.toStringAsFixed(0)}°', color: const Color(0xFF4A9EFF)),
          const Spacer(),
          const Text('SKY MAP',
              style: TextStyle(color: Colors.white54, fontSize: 11,
                  letterSpacing: 4, fontWeight: FontWeight.w300)),
          const Spacer(),
          _hudChip(icon: Icons.height_rounded, label: 'ALT',
              value: '${altDeg.toStringAsFixed(0)}°', color: const Color(0xFF4AEFB0)),
        ],
      ),
    );
  }

  Widget _buildBottomHUD() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.6), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, MediaQuery.of(context).padding.bottom + 12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_rounded, color: Color(0xFF4A9EFF), size: 14),
          SizedBox(width: 6),
          Text('Tap a planet or the Sun for details',
              style: TextStyle(color: Color(0x99A8C8FF), fontSize: 12, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _hudChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 9, letterSpacing: 1)),
          Text(value,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}
