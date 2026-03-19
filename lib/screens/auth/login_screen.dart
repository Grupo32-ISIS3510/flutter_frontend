import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:second_serving_frontend/config/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 48),
                _buildLogo(),
                const SizedBox(height: 36),
                _buildTabs(),
                const SizedBox(height: 8),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLoginForm(),
                      _buildSignUpForm(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(painter: _LogoIconPainter()),
        ),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Second',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                height: 1.1,
              ),
            ),
            Text(
              'Serving',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.secondary,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
      indicatorWeight: 3,
      labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 16),
      tabs: const [
        Tab(text: 'Login'),
        Tab(text: 'Sign-up'),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        _buildUnderlineField(
          label: 'Email address',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        _buildUnderlineField(
          label: 'Password',
          controller: _passwordController,
          obscure: true,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Forgot password?',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 14,
            ),
          ),
        ),
        const Spacer(),
        Center(
          child: SizedBox(
            width: 220,
            height: 52,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
                textStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              child: const Text('Login'),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        _buildUnderlineField(
          label: 'Full name',
          controller: _regNameController,
        ),
        const SizedBox(height: 24),
        _buildUnderlineField(
          label: 'Email address',
          controller: _regEmailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        _buildUnderlineField(
          label: 'Password',
          controller: _regPasswordController,
          obscure: true,
        ),
        const Spacer(),
        Center(
          child: SizedBox(
            width: 220,
            height: 52,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
                textStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              child: const Text('Sign up'),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUnderlineField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        filled: false,
        border: const UnderlineInputBorder(),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.textLight),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.only(bottom: 8),
      ),
    );
  }
}

class _LogoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final platePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy + 4), size.width * 0.35, platePaint);

    final forkPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final forkX = cx - 4;
    canvas.drawLine(
        Offset(forkX, cy + size.height * 0.28),
        Offset(forkX, cy - size.height * 0.05),
        forkPaint);
    for (var dx = -6.0; dx <= 6.0; dx += 6.0) {
      canvas.drawLine(
          Offset(forkX + dx, cy - size.height * 0.05),
          Offset(forkX + dx, cy - size.height * 0.22),
          forkPaint);
    }

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
