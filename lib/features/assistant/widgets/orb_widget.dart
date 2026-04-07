import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ai_assistant/core/models/assistant_state.dart';

class OrbWidget extends StatefulWidget {
  final AssistantState state;
  final List<double> waveAmplitudes;
  final VoidCallback onTap;

  const OrbWidget({
    super.key,
    required this.state,
    required this.waveAmplitudes,
    required this.onTap,
  });

  @override
  State<OrbWidget> createState() => _OrbWidgetState();
}

class _OrbWidgetState extends State<OrbWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  // Persisted across frames — never trigger rebuild, just plain fields
  double _smoothVoice = 0.0;
  double _smoothR = 110.0;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String get mode {
    switch (widget.state) {
      case AssistantState.listening:
        return 'pulse';
      case AssistantState.thinking:
      case AssistantState.speaking:
        return 'rage';
      default:
        return 'bass';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 300,
        height: 300,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            return CustomPaint(
              painter: _OrbPainter(
                t: controller.value,
                mode: mode,
                wave: widget.waveAmplitudes,
                smoothVoice: _smoothVoice,
                smoothR: _smoothR,
                onUpdate: (sv, sr) {
                  // Direct field mutation — no setState, no rebuild overhead
                  _smoothVoice = sv;
                  _smoothR = sr;
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final String mode;
  final List<double> wave;
  final double smoothVoice;
  final double smoothR;
  final void Function(double sv, double sr) onUpdate;

  _OrbPainter({
    required this.t,
    required this.mode,
    required this.wave,
    required this.smoothVoice,
    required this.smoothR,
    required this.onUpdate,
  });

  static const double ORB_R = 110;

  late final List<_Particle> wisps = List.generate(
    200,
    (_) => _Particle.wisp(),
  );
  late final List<_Particle> sparks = List.generate(
    130,
    (_) => _Particle.spark(),
  );

  Map get m {
    switch (mode) {
      case 'pulse':
        return {
          "c": [
            const Color(0xFFBB77FF),
            const Color(0xFF9944FF),
            const Color(0xFFDD99FF),
            const Color(0xFFFFFFFF),
          ],
          "core1": const Color(0xFFCC88FF),
          "core2": const Color(0xFF8833EE),
          "glow": const Color(0xFF6600CC),
          "wispSpd": 0.20,
          "sparkSpd": 0.55,
          "ints": 2.2,
          "breathe": true,
          "breatheFreq": 0.9,
          "breatheAmp": 0.22,
        };
      case 'rage':
        return {
          "c": [
            const Color(0xFFFF00CC),
            const Color(0xFFCC00FF),
            const Color(0xFF00CFFF),
            const Color(0xFFFFFFFF),
          ],
          "core1": const Color(0xFFFF00CC),
          "core2": const Color(0xFF9900FF),
          "glow": const Color(0xFFFF0066),
          "wispSpd": 0.35,
          "sparkSpd": 1.10,
          "ints": 1.6,
          "breathe": true,
          "breatheFreq": 2.2,
          "breatheAmp": 0.14,
        };
      default:
        return {
          "c": [
            const Color(0xFF00EEFF),
            const Color(0xFF0088FF),
            const Color(0xFFFF3366),
            const Color(0xFFFFFFFF),
          ],
          "core1": const Color(0xFF00EEFF),
          "core2": const Color(0xFF0044FF),
          "glow": const Color(0xFF0066CC),
          "wispSpd": 0.14,
          "sparkSpd": 0.42,
          "ints": 1.0,
          "breathe": false,
          "breatheFreq": 0.5,
          "breatheAmp": 0.06,
        };
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    final wispT = t * (m["wispSpd"] as double);
    final sparkT = t * (m["sparkSpd"] as double);

    double pulse = 1.0;
    var sv = smoothVoice;

    if (mode == 'pulse') {
      final voiceAmp = wave.isNotEmpty
          ? wave.reduce((a, b) => a > b ? a : b)
          : 0.0;

      final riseSpeed = 1.00;
      final decaySpeed = 1.00;

      final lerpFactor = voiceAmp > sv ? riseSpeed : decaySpeed;
      sv += (voiceAmp - sv) * lerpFactor;

      // Idle breath only in silence so default size = exactly ORB_R
      final idleBreath = sv < 0.01 ? sin(t * 70.0) * 0.025 : 0.0;

      final voiceLift = sv * 0.65;
      pulse = 1.0 + idleBreath + voiceLift;
    } else if (m["breathe"] as bool) {
      final freq = m["breatheFreq"] as double;
      final amp = m["breatheAmp"] as double;
      pulse =
          1.0 +
          sin(wispT * freq * pi * 2) * amp +
          sin(wispT * freq * pi * 4) * (amp * 0.25);
    }

    final targetR = ORB_R * pulse;
    var sr = smoothR;
    sr += (targetR - sr) * 0.18;

    // Write back to state fields — no setState, zero rebuild cost
    onUpdate(sv, sr);

    final r = sr;

    // 💎 resin polish — contrast+saturation boost over everything
    final resinPaint = Paint()
      ..colorFilter = const ColorFilter.matrix(<double>[
        1.4,
        -0.1,
        -0.1,
        0.0,
        -25.0,
        -0.1,
        1.4,
        -0.1,
        0.0,
        -25.0,
        -0.1,
        -0.1,
        1.4,
        0.0,
        -25.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
      ]);
    canvas.saveLayer(
      Rect.fromCircle(center: center, radius: r * 2),
      resinPaint,
    );

    _drawSphereBody(canvas, center, r);
    _drawParticles(canvas, center, r, wispT, sparkT);
    _drawSheen(canvas, center, r);

    canvas.restore();
  }

  void _drawSphereBody(Canvas canvas, Offset c, double r) {
    final colors = m["c"] as List<Color>;

    for (int i = 3; i >= 0; i--) {
      final ar = r * (1.45 + i * 0.28);
      final col = colors[i % colors.length];
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            col.withOpacity(0.0),
            col.withOpacity(0.18),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: ar));
      canvas.drawCircle(c, ar, paint);
    }

    final core = Paint()
      ..shader = RadialGradient(
        colors: [
          (m["core1"] as Color).withOpacity(1.0),
          (m["core2"] as Color).withOpacity(0.85),
          (m["glow"] as Color).withOpacity(0.55),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, core);

    final rimColor = m["core1"] as Color;
    final rim = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          rimColor.withOpacity(0.0),
          rimColor.withOpacity(0.45),
          rimColor.withOpacity(0.0),
        ],
        stops: const [0.0, 0.60, 0.88, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r * 1.08, rim);

    // ✨ core specular shine
    final shineAngle = t * 1200.0;
    final shineX = c.dx + cos(shineAngle) * r * 0.28;
    final shineY = c.dy + sin(shineAngle) * r * 0.18;
    final coreShineBrightness = (sin(t * 4000.0) + 1) / 2;
    final coreShineOpacity = 0.30 + coreShineBrightness * 0.45;
    final coreShine = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withOpacity(coreShineOpacity),
              Colors.white.withOpacity(0.0),
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(shineX, shineY), radius: r * 0.22),
          );
    canvas.drawCircle(Offset(shineX, shineY), r * 0.22, coreShine);
  }

  void _drawParticles(
    Canvas canvas,
    Offset c,
    double r,
    double wispT,
    double sparkT,
  ) {
    final pts = <_RenderPoint>[];
    final colors = m["c"] as List<Color>;

    for (var w in wisps) {
      w.update(m["wispSpd"] as double);
      pts.add(_project(w, r));
    }
    for (var s in sparks) {
      s.update(m["sparkSpd"] as double);
      pts.add(_project(s, r));
    }

    pts.sort((a, b) => a.z.compareTo(b.z));

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));

    for (var p in pts) {
      final depth = pow((p.z + r) / (r * 2), 0.6).toDouble();
      final col = colors[p.ci % colors.length];
      final pos = Offset(c.dx + p.x, c.dy + p.y);
      final bt = p.isWisp ? wispT : sparkT;

      if (p.isWisp) {
        final sz = p.size * (1 + sin(bt * 1.2 + p.offset) * 0.25) * p.persp;
        final wispShimmer = (sin(bt * 3.0 + p.offset * 2.3) + 1) / 2;
        final wispBase = 0.40 + wispShimmer * 0.45;
        final paint = Paint()
          ..shader = RadialGradient(
            colors: [
              col.withOpacity(wispBase * depth),
              col.withOpacity((wispBase * 0.35) * depth),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: pos, radius: sz));
        canvas.drawCircle(pos, sz, paint);
      } else {
        final sz = p.size * (1 + sin(bt * 1.8 + p.offset) * 0.35) * p.persp;
        final sparkShimmer = (sin(bt * 4.0 + p.offset * 5.1) + 1) / 2;
        final sparkGlowBase = 0.55 + sparkShimmer * 0.45;
        final glow = Paint()
          ..shader = RadialGradient(
            colors: [
              col.withOpacity(sparkGlowBase * depth),
              col.withOpacity((sparkGlowBase * 0.38) * depth),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: pos, radius: sz * 5));
        canvas.drawCircle(pos, sz * 5, glow);
      }
    }

    canvas.restore();
  }

  _RenderPoint _project(_Particle p, double r) {
    final x3 = r * sin(p.theta) * cos(p.phi);
    final y3 = r * cos(p.theta);
    final z3 = r * sin(p.theta) * sin(p.phi);
    final persp = 1 + z3 / (ORB_R * 3.5);
    return _RenderPoint(
      x: x3 * persp,
      y: -y3 * persp,
      z: z3,
      size: p.size,
      ci: p.ci,
      persp: persp,
      offset: p.offset,
      isWisp: p.isWisp,
    );
  }

  void _drawSheen(Canvas canvas, Offset c, double r) {
    final p1 = Paint()
      ..shader =
          RadialGradient(
            colors: [Colors.white.withOpacity(0.40), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(c.dx - r * 0.28, c.dy - r * 0.28),
              radius: r * 0.38,
            ),
          );
    canvas.drawCircle(Offset(c.dx - r * 0.28, c.dy - r * 0.28), r * 0.38, p1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Particle {
  double phi, theta;
  double phiSpeed, thetaSpeed;
  double depth, size;
  int ci;
  double offset;
  bool isWisp;

  _Particle(
    this.phi,
    this.theta,
    this.phiSpeed,
    this.thetaSpeed,
    this.depth,
    this.size,
    this.ci,
    this.offset,
    this.isWisp,
  );

  factory _Particle.wisp() {
    final r = Random();
    return _Particle(
      r.nextDouble() * pi * 2,
      r.nextDouble() * pi,
      (0.00003 + r.nextDouble() * 0.00005) * (r.nextBool() ? 1 : -1),
      (0.00001 + r.nextDouble() * 0.00003) * (r.nextBool() ? 1 : -1),
      0.85 + r.nextDouble() * 0.18,
      8 + r.nextDouble() * 18,
      r.nextInt(4),
      r.nextDouble() * pi * 2,
      true,
    );
  }

  factory _Particle.spark() {
    final r = Random();
    return _Particle(
      r.nextDouble() * pi * 2,
      r.nextDouble() * pi,
      (0.00008 + r.nextDouble() * 0.0001) * (r.nextBool() ? 1 : -1),
      (0.00004 + r.nextDouble() * 0.00006) * (r.nextBool() ? 1 : -1),
      0.7 + r.nextDouble() * 0.32,
      0.8 + r.nextDouble() * 1.8,
      r.nextInt(4),
      r.nextDouble() * pi * 2,
      false,
    );
  }

  void update(double spd) {
    phi += phiSpeed * spd;
    theta += thetaSpeed * spd;
    if (theta < 0) theta += pi;
    if (theta > pi) theta -= pi;
  }
}

class _RenderPoint {
  final double x, y, z, size, persp, offset;
  final int ci;
  final bool isWisp;

  _RenderPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.size,
    required this.ci,
    required this.persp,
    required this.offset,
    required this.isWisp,
  });
}
