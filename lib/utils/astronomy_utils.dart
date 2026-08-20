import 'dart:math';

class AltAz {
  final double altitude; // degrees
  final double azimuth;  // degrees, 0=N, 90=E, 180=S, 270=W

  AltAz(this.altitude, this.azimuth);
}

class AstronomyUtils {
  // RA/Dec -> Altitude/Azimuth conversion
  // ra in hours, dec in degrees, lat/lon in degrees, time in UTC
  static AltAz calculateAltAz(
      double ra, double dec, double lat, double lon, DateTime time) {
    final double d = time.difference(DateTime.utc(2000, 1, 1, 12)).inSeconds / 86400.0;

    // Greenwich Mean Sidereal Time (degrees)
    double gmst = (280.46061837 + 360.98564736629 * d) % 360.0;
    if (gmst < 0) gmst += 360.0;

    // Local Sidereal Time
    double lst = (gmst + lon) % 360.0;
    if (lst < 0) lst += 360.0;

    // Hour angle in degrees
    double ha = lst - ra * 15.0;

    final double decR = dec * pi / 180.0;
    final double latR = lat * pi / 180.0;
    final double haR = ha * pi / 180.0;

    // Altitude
    final double sinAlt =
        sin(decR) * sin(latR) + cos(decR) * cos(latR) * cos(haR);
    final double altR = asin(sinAlt.clamp(-1.0, 1.0));

    // Azimuth (N=0, E=90)
    final double cosAz =
        (sin(decR) - sin(latR) * sinAlt) / (cos(latR) * cos(altR));
    double az = acos(cosAz.clamp(-1.0, 1.0)) * 180.0 / pi;
    if (sin(haR) > 0) az = 360.0 - az;

    return AltAz(altR * 180.0 / pi, az);
  }

  /// Full Keplerian orbital mechanics for solar system bodies.
  /// Returns Map of name -> [RA (hours), Dec (degrees)]
  /// Based on Paul Schlyter's "How to compute planetary positions"
  /// Accuracy: within ~1° for 1990–2050.
  static Map<String, List<double>> getApproximatePlanetsRADec(DateTime time) {
    final double d = time.difference(DateTime.utc(2000, 1, 1, 12)).inSeconds / 86400.0;
    final double oblecl = (23.4393 - 3.563e-7 * d) * pi / 180.0; // obliquity of ecliptic

    // --- SUN ---
    final sun = _sunEcliptic(d);
    final sunEq = _eclToEquatorial(sun[0], sun[1], oblecl);

    // --- MOON ---
    final moon = _moonEcliptic(d);
    final moonEq = _eclToEquatorial(moon[0], moon[1], oblecl);

    // --- PLANETS: heliocentric -> geocentric -> RA/Dec ---
    // Earth position (needed for geocentric coords)
    final earthHel = _planetHeliocentric(d, _earth);
    final earthX = earthHel[0];
    final earthY = earthHel[1];

    final result = <String, List<double>>{
      'Sun': sunEq,
      'Moon': moonEq,
    };

    for (final entry in _planets.entries) {
      final hel = _planetHeliocentric(d, entry.value);
      // Geocentric ecliptic coords
      double xgeo = hel[0] - earthX;
      double ygeo = hel[1] - earthY;
      double zgeo = hel[2];

      // Convert to equatorial
      double xeq = xgeo;
      double yeq = ygeo * cos(oblecl) - zgeo * sin(oblecl);
      double zeq = ygeo * sin(oblecl) + zgeo * cos(oblecl);

      double ra = atan2(yeq, xeq) * 180.0 / pi;
      if (ra < 0) ra += 360.0;
      double dec = atan2(zeq, sqrt(xeq * xeq + yeq * yeq)) * 180.0 / pi;

      result[entry.key] = [ra / 15.0, dec]; // RA in hours
    }

    return result;
  }

  // --- Sun ecliptic longitude & latitude ---
  static List<double> _sunEcliptic(double d) {
    final double w = 282.9404 + 4.70935e-5 * d; // longitude of perihelion
    final double e = 0.016709 - 1.151e-9 * d;   // eccentricity
    double M = _norm360(356.0470 + 0.9856002585 * d); // mean anomaly

    final double Mrad = M * pi / 180.0;
    // Eccentric anomaly (first-order approximation)
    final double E = M + (180.0 / pi) * e * sin(Mrad) * (1.0 + e * cos(Mrad));
    final double Erad = E * pi / 180.0;

    final double xv = cos(Erad) - e;
    final double yv = sqrt(1.0 - e * e) * sin(Erad);
    final double v = atan2(yv, xv) * 180.0 / pi; // true anomaly

    double lon = _norm360(v + w); // ecliptic longitude
    return [lon, 0.0]; // Sun stays on ecliptic plane (lat ≈ 0)
  }

  // Convert ecliptic lon/lat (degrees) to equatorial RA (hours) / Dec (degrees)
  static List<double> _eclToEquatorial(double lonDeg, double latDeg, double oblR) {
    final double lonR = lonDeg * pi / 180.0;
    final double latR = latDeg * pi / 180.0;

    final double x = cos(lonR) * cos(latR);
    final double y = sin(lonR) * cos(latR);
    final double z = sin(latR);

    final double yeq = y * cos(oblR) - z * sin(oblR);
    final double zeq = y * sin(oblR) + z * cos(oblR);

    double ra = atan2(yeq, x) * 180.0 / pi;
    if (ra < 0) ra += 360.0;
    final double dec = atan2(zeq, sqrt(x * x + yeq * yeq)) * 180.0 / pi;

    return [ra / 15.0, dec]; // [RA hours, Dec degrees]
  }

  // --- Moon ecliptic position ---
  static List<double> _moonEcliptic(double d) {
    // Moon's orbital elements
    final double N = _norm360(125.1228 - 0.0529538083 * d); // long. of asc. node
    final double i = 5.1454; // inclination
    final double w = _norm360(318.0634 + 0.1643573223 * d); // arg. of perigee
    // final double a = 60.2666; // semi-major axis (Earth radii) - unused for direction
    final double e = 0.054900; // eccentricity
    double M = _norm360(115.3654 + 13.0649929509 * d); // mean anomaly

    final double Mrad = M * pi / 180.0;
    // Eccentric anomaly (iterate for better accuracy)
    double E = M + (180.0 / pi) * e * sin(Mrad) * (1.0 + e * cos(Mrad));
    for (int k = 0; k < 3; k++) {
      final double Erad = E * pi / 180.0;
      E = E - (E - (180.0 / pi) * e * sin(Erad) - M) / (1 - e * cos(Erad));
    }
    final double Erad = E * pi / 180.0;

    final double xv = cos(Erad) - e;
    final double yv = sqrt(1.0 - e * e) * sin(Erad);
    final double v = atan2(yv, xv) * 180.0 / pi;

    // Moon's ecliptic coords in 3D
    final double wR = w * pi / 180.0;
    final double NR = N * pi / 180.0;
    final double iR = i * pi / 180.0;
    final double vR = v * pi / 180.0;

    final double xeclR = cos(NR) * cos(vR + wR) - sin(NR) * sin(vR + wR) * cos(iR);
    final double yeclR = sin(NR) * cos(vR + wR) + cos(NR) * sin(vR + wR) * cos(iR);
    final double zeclR = sin(vR + wR) * sin(iR);

    final double lon = atan2(yeclR, xeclR) * 180.0 / pi;
    final double lat = asin(zeclR) * 180.0 / pi;

    return [_norm360(lon), lat];
  }

  // Keplerian elements for each planet at J2000 + daily rates
  // Format: [N0, Nd, i0, id, w0, wd, a, e0, ed, M0, Md]
  // N = long. of asc. node, i = inclination, w = arg. of perihelion
  // a = semi-major axis (AU), e = eccentricity, M = mean anomaly
  static const Map<String, _PlanetElements> _planets = {
    'Mercury': _PlanetElements(
      N0: 48.3313, Nd: 3.24587e-5,
      i0: 7.0047, id: 5.00e-8,
      w0: 29.1241, wd: 1.01444e-5,
      a: 0.387098,
      e0: 0.205635, ed: 5.59e-10,
      M0: 168.6562, Md: 4.0923344368,
    ),
    'Venus': _PlanetElements(
      N0: 76.6799, Nd: 2.46590e-5,
      i0: 3.3946, id: 2.75e-8,
      w0: 54.8910, wd: 1.38374e-5,
      a: 0.723330,
      e0: 0.006773, ed: -1.302e-9,
      M0: 48.0052, Md: 1.6021302244,
    ),
    'Mars': _PlanetElements(
      N0: 49.5574, Nd: 2.11081e-5,
      i0: 1.8497, id: -1.78e-8,
      w0: 286.5016, wd: 2.92961e-5,
      a: 1.523688,
      e0: 0.093405, ed: 2.516e-9,
      M0: 18.6021, Md: 0.5240207766,
    ),
    'Jupiter': _PlanetElements(
      N0: 100.4542, Nd: 2.76854e-5,
      i0: 1.3030, id: -1.557e-7,
      w0: 273.8777, wd: 1.64505e-5,
      a: 5.20256,
      e0: 0.048498, ed: 4.469e-9,
      M0: 19.8950, Md: 0.0830853001,
    ),
    'Saturn': _PlanetElements(
      N0: 113.6634, Nd: 2.38980e-5,
      i0: 2.4886, id: -1.081e-7,
      w0: 339.3939, wd: 2.97661e-5,
      a: 9.55475,
      e0: 0.055546, ed: -9.499e-9,
      M0: 316.9670, Md: 0.0334442282,
    ),
    'Uranus': _PlanetElements(
      N0: 74.0005, Nd: 1.3978e-5,
      i0: 0.7733, id: 1.9e-8,
      w0: 96.6612, wd: 3.0565e-5,
      a: 19.18171,
      e0: 0.047318, ed: 7.45e-9,
      M0: 142.5905, Md: 0.011725806,
    ),
    'Neptune': _PlanetElements(
      N0: 131.7806, Nd: 3.0173e-5,
      i0: 1.7700, id: -2.55e-7,
      w0: 272.8461, wd: -6.027e-6,
      a: 30.05826,
      e0: 0.008606, ed: 2.15e-9,
      M0: 260.2471, Md: 0.005995147,
    ),
  };

  // Earth elements (for geocentric transform)
  static const _PlanetElements _earth = _PlanetElements(
    N0: 0.0, Nd: 0.0,
    i0: 0.0, id: 0.0,
    w0: 282.9404, wd: 4.70935e-5,
    a: 1.0,
    e0: 0.016709, ed: -1.151e-9,
    M0: 356.0470, Md: 0.9856002585,
  );

  // Compute heliocentric ecliptic X, Y, Z (AU) for a planet
  static List<double> _planetHeliocentric(double d, _PlanetElements p) {
    final double N = _norm360(p.N0 + p.Nd * d);
    final double i = p.i0 + p.id * d;
    final double w = _norm360(p.w0 + p.wd * d);
    final double a = p.a;
    final double e = p.e0 + p.ed * d;
    double M = _norm360(p.M0 + p.Md * d);

    // Solve Kepler's equation iteratively
    double E = M + (180.0 / pi) * e * sin(M * pi / 180.0) * (1.0 + e * cos(M * pi / 180.0));
    for (int k = 0; k < 5; k++) {
      final double Erad = E * pi / 180.0;
      E = E - (E - (180.0 / pi) * e * sin(Erad) - M) / (1.0 - e * cos(Erad));
    }

    final double Erad = E * pi / 180.0;
    final double xv = a * (cos(Erad) - e);
    final double yv = a * (sqrt(1.0 - e * e) * sin(Erad));

    // True anomaly and radius
    final double v = atan2(yv, xv) * 180.0 / pi;
    final double r = sqrt(xv * xv + yv * yv);

    // Heliocentric ecliptic coordinates (3D)
    final double NR = N * pi / 180.0;
    final double iR = i * pi / 180.0;
    final double vwR = (v + w) * pi / 180.0;

    final double xh = r * (cos(NR) * cos(vwR) - sin(NR) * sin(vwR) * cos(iR));
    final double yh = r * (sin(NR) * cos(vwR) + cos(NR) * sin(vwR) * cos(iR));
    final double zh = r * sin(vwR) * sin(iR);

    return [xh, yh, zh];
  }

  static double _norm360(double deg) {
    double r = deg % 360.0;
    return r < 0 ? r + 360.0 : r;
  }
}

class _PlanetElements {
  final double N0, Nd; // longitude of ascending node
  final double i0, id; // inclination
  final double w0, wd; // argument of perihelion
  final double a;      // semi-major axis (AU)
  final double e0, ed; // eccentricity
  final double M0, Md; // mean anomaly

  const _PlanetElements({
    required this.N0, required this.Nd,
    required this.i0, required this.id,
    required this.w0, required this.wd,
    required this.a,
    required this.e0, required this.ed,
    required this.M0, required this.Md,
  });
}
