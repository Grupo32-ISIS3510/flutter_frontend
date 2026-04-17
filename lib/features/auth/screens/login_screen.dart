import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/features/auth/providers/auth_provider.dart';

// StatefulWidget porque la pantalla guarda estado mutable: texto del usuario
// en los TextField y la pestaña activa del TabController.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// SingleTickerProviderStateMixin: provee un Ticker (sincronizado con el refresco
// de pantalla, 60/120 fps) que el TabController usa para animar el cambio de
// pestaña. Si tuvieras varios controllers animados, usarías TickerProviderStateMixin.
class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Cada TextEditingController mantiene un buffer del texto y notifica cambios.
  // Si NO se hace dispose(), se queda en memoria → memory leak.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // length: 2 = pestañas Login / Sign-up. vsync: this aprovecha el Ticker del mixin.
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // Liberar TODOS los recursos antes de que el State sea destruido.
    // Equivale a liberar Cursors / unregister de BroadcastReceivers en Android nativo.
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();        // super.dispose() SIEMPRE al final
  }

  Future<void> _handleLogin() async {
    // .trim() en email para tolerar espacios accidentales del autocomplete.
    final email = _emailController.text.trim();
    // NO se hace trim al password: los espacios pueden ser parte de la contraseña.
    final password = _passwordController.text;

    // VALIDACIÓN CLIENT-SIDE: ahorra una llamada de red obvia. La validación
    // real igual se hace en backend (nunca confiar solo en el cliente).
    if (email.isEmpty || password.isEmpty) {
      _showError('Por favor completa todos los campos');
      return;
    }
    if (!email.contains('@')) {
      _showError('Ingresa un correo válido');
      return;
    }

    // context.read<T>() = obtener provider SIN suscribirse a cambios.
    // Lo correcto en handlers (no necesitan rebuild aquí, la UI ya escucha con watch).
    final auth = context.read<AuthProvider>();
    auth.clearError();           // Limpia banner de error previo
    final success = await auth.login(email: email, password: password);

    // mounted: durante el await, el widget pudo haberse desmontado (usuario
    // tocó back, etc). Llamar context.go() en widget desmontado = crash/warning.
    // Es como verificar !isFinishing && !isDestroyed antes de startActivity en Android.
    if (success && mounted) {
      context.go('/home');       // go() reemplaza la pila; push() apilaría
    }
  }

  Future<void> _handleRegister() async {
    // Misma validación que login + chequeo de longitud mínima de password.
    final name = _regNameController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Por favor completa todos los campos');
      return;
    }
    if (!email.contains('@')) {
      _showError('Ingresa un correo válido');
      return;
    }
    if (password.length < 6) {
      _showError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final success = await auth.register(
      email: email,
      fullName: name,
      password: password,
    );

    if (success && mounted) {
      context.go('/home');
    }
  }

  // Helper para mostrar errores transitorios (validación local) vía SnackBar.
  // Los errores de red persistentes se muestran en el banner superior.
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,    // Estilo flotante Material 3
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // context.watch<T>() = SE SUSCRIBE al provider. Cada notifyListeners()
    // dispara este build de nuevo → la UI reacciona sin código manual.
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      // SafeArea evita que el contenido quede tapado por notch/status bar.
      body: SafeArea(
        // SingleChildScrollView para que el teclado no recorte la pantalla
        // cuando el usuario escribe (overflow vertical).
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 48),
                _buildLogo(),
                const SizedBox(height: 36),
                // Spread collection-if (...[]): inserta varios widgets solo
                // si auth.error != null. Evita Visibility/SizedBox.shrink().
                if (auth.error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // withValues(alpha:) = API moderna (Flutter 3.27+)
                      // que reemplaza withOpacity() en espacio de color amplio.
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        // Expanded para que el texto largo se ajuste sin overflow.
                        Expanded(
                          child: Text(
                            auth.error!,        // ! porque ya validamos != null
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13),
                          ),
                        ),
                        // Tap en la X → llama clearError() → notifyListeners()
                        // → este build vuelve a correr y el banner desaparece.
                        GestureDetector(
                          onTap: auth.clearError,
                          child: const Icon(Icons.close,
                              color: AppColors.error, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildTabs(),
                const SizedBox(height: 8),
                SizedBox(
                  height: 400,             // Altura fija requerida por TabBarView dentro de scroll
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLoginForm(auth),
                      _buildSignUpForm(auth),
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

  Widget _buildLoginForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        _buildUnderlineField(
          label: 'Email address',
          controller: _emailController,
          // keyboardType cambia el layout del teclado (muestra @ y .com en Android).
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        _buildUnderlineField(
          label: 'Password',
          controller: _passwordController,
          obscure: true,                     // Oculta el texto con puntos
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {},                  // TODO: implementar recuperación
          style: TextButton.styleFrom(
            // Estos 3 trucos juntos hacen el botón "minimal": cero padding,
            // sin tamaño mínimo material, y sin tap-target inflado.
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
        // Spacer empuja el botón al fondo cuando hay espacio sobrante.
        const Spacer(),
        Center(
          child: SizedBox(
            width: 220,
            height: 52,
            // PATRÓN UI DECLARATIVA: el botón cambia de aspecto y se deshabilita
            // automáticamente cuando auth.isLoading == true. No hay setState manual:
            // todo viene del rebuild que dispara el provider.
            child: ElevatedButton(
              // onPressed: null deshabilita visualmente el botón (gris).
              onPressed: auth.isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),    // Botón pill
                ),
                elevation: 0,
                textStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              // Spinner inline mientras la petición está en vuelo.
              child: auth.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Login'),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSignUpForm(AuthProvider auth) {
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
              onPressed: auth.isLoading ? null : _handleRegister,
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
              child: auth.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sign up'),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Helper privado para no repetir InputDecoration en cada TextField.
  // Patrón: extraer widgets reutilizables como métodos cuando son privados al State.
  Widget _buildUnderlineField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,                  // Conecta el text con el state
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        filled: false,                         // Sin fondo de relleno
        // Tres estados visuales del borde: default / habilitado / con foco.
        // Cuando el usuario tapea el campo, el borde se vuelve verde y grueso.
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
