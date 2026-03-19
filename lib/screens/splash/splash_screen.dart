import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:second_serving_frontend/config/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) context.go('/login');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Arcos decorativos en esquina inferior derecha
          Positioned(
            bottom: -120,
            right: -120,
            child: SizedBox(
              width: 360,
              height: 360,
              child: CustomPaint(painter: _ArcsPainter()),
            ),
          ),
          // Logo centrado
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CustomPaint(painter: _LogoIconPainter()),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Second',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Serving',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Plato/círculo verde de fondo
    final platePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy + 4), size.width * 0.35, platePaint);

    // Tenedor (naranja)
    final forkPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final forkX = cx - 4;
    // Mango
    canvas.drawLine(
        Offset(forkX, cy + size.height * 0.28),
        Offset(forkX, cy - size.height * 0.05),
        forkPaint);
    // Dientes
    for (var dx = -6.0; dx <= 6.0; dx += 6.0) {
      canvas.drawLine(
          Offset(forkX + dx, cy - size.height * 0.05),
          Offset(forkX + dx, cy - size.height * 0.22),
          forkPaint);
    }

    // Hoja verde
    final leafPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    final leafPath = Path();
    final leafCx = cx + 12.0;
    final leafCy = cy - size.height * 0.18;
    leafPath.moveTo(leafCx, leafCy - 10);
    leafPath.quadraticBezierTo(leafCx + 14, leafCy, leafCx, leafCy + 10);
    leafPath.quadraticBezierTo(leafCx - 14, leafCy, leafCx, leafCy - 10);
    canvas.drawPath(leafPath, leafPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArcsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width, size.height);

    // Arco verde (exterior)
    final greenPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 45;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.42),
      pi,
      pi / 2,
      false,
      greenPaint,
    );

    // Arco naranja (interior)
    final orangePaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 35;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.28),
      pi,
      pi / 2,
      false,
      orangePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
