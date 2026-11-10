import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reflejo diagonal de Platino: 1,8 segundos de barrido y 4,2 de pausa.
class LibraryPlatinumShine extends StatefulWidget {
  const LibraryPlatinumShine({super.key});

  @override
  State<LibraryPlatinumShine> createState() => _LibraryPlatinumShineState();
}

class _LibraryPlatinumShineState extends State<LibraryPlatinumShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase;

  @override
  void initState() {
    super.initState();
    _phase =
        AnimationController(vsync: this, duration: const Duration(seconds: 6));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context)) {
      if (!_phase.isAnimating) _phase.repeat();
    } else {
      _phase.stop();
      _phase.value = 0;
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(painter: _PlatinumShinePainter(_phase)),
        ),
      );
}

class _PlatinumShinePainter extends CustomPainter {
  _PlatinumShinePainter(this.phase) : super(repaint: phase);
  final Animation<double> phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || phase.value == 0 || phase.value >= .3) return;
    final progress = Curves.easeInOut.transform(phase.value / .3);
    final center = (-.78 + 2.56 * progress) * size.width;
    final width = size.width * .416;
    final beam =
        Rect.fromLTWH(-width / 2, -size.height * 2, width, size.height * 4);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(center, size.height / 2);
    canvas.rotate(25 * math.pi / 180);
    canvas.drawRect(
        beam,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x00FFFFFF), Color(0x70FFFFFF), Color(0x00FFFFFF)],
            stops: [0, .5, 1],
          ).createShader(beam));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlatinumShinePainter oldDelegate) =>
      oldDelegate.phase != phase;
}
