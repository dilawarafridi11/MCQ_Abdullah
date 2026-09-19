import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../models/login_preview.dart';
import '../providers/auth_providers.dart';

/// Premium luxury login screen — black & gold, carpet showroom backdrop,
/// glassmorphism cards, gold gradient elements and rich entrance animations.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFF7D488);
  static const _goldDark = Color(0xFFB8860B);
  static const _rememberKey = 'login_remember_email';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;

  Timer? _previewTimer;
  LoginPreview? _preview;
  bool _previewLoading = false;
  String? _selectedShopId;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.3, curve: Curves.easeOut),
  );
  late final Animation<double> _taglineFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.12, 0.42, curve: Curves.easeOut),
  );
  late final Animation<double> _dividerFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
  );
  late final Animation<double> _cardFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.28, 0.85, curve: Curves.easeOut),
  );
  late final Animation<Offset> _cardSlide = Tween<Offset>(
    begin: const Offset(0, 0.14),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 0.9, curve: Curves.easeOutCubic),
    ),
  );

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_schedulePreview);
    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _controller.dispose();
    _previewTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_rememberKey);
    if (email == null || email.isEmpty) return;
    _emailController.text = email;
    if (mounted) setState(() => _rememberMe = true);
  }

  void _schedulePreview() {
    _previewTimer?.cancel();
    if (Validators.emailOrPhone(_emailController.text.trim()) != null) {
      if (_preview != null || _previewLoading) {
        setState(() {
          _preview = null;
          _selectedShopId = null;
          _previewLoading = false;
        });
      }
      return;
    }
    _previewTimer = Timer(const Duration(milliseconds: 450), _lookupPreview);
  }

  Future<void> _lookupPreview() async {
    if (!mounted) return;
    setState(() => _previewLoading = true);
    try {
      final preview = await ref
          .read(authRepositoryProvider)
          .previewLogin(_emailController.text);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _previewLoading = false;
        if (preview.isManager && preview.shops.isNotEmpty) {
          _selectedShopId = _selectedShopId ?? preview.shops.first.id;
        } else {
          _selectedShopId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewLoading = false;
        _selectedShopId = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final isManager = _preview?.isManager == true;
    if (isManager && _selectedShopId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your shop to continue.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final fcmToken = await FcmService.instance.getToken();
    final ok = await ref.read(authControllerProvider.notifier).login(
          _emailController.text,
          _passwordController.text,
          shopId: isManager ? _selectedShopId : null,
          fcmToken: fcmToken,
        );
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString(_rememberKey, _emailController.text.trim());
      } else {
        await prefs.remove(_rememberKey);
      }
      return;
    }
    final error =
        ref.read(authControllerProvider).error ?? 'Login failed. Please try again.';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: AppColors.danger, size: 36),
        title: const Text('Login Failed'),
        content: Text(
          _friendlyError(error),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('unauthorized') ||
        lower.contains('invalid email') ||
        lower.contains('invalid credentials')) {
      return 'Incorrect email or password. Please check your credentials and try again.';
    }
    if (lower.contains('selected shop') || lower.contains('assigned shop')) {
      return 'The selected shop is not valid for this account.';
    }
    if (lower.contains('deactivated')) {
      return 'This account has been deactivated. Contact the admin.';
    }
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout')) {
      return 'Could not reach the server. Check your internet connection and that the backend is running.';
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(
      authControllerProvider.select((s) => s.status == AuthStatus.authenticating),
    );
    final isManager = _preview?.isManager == true;
    final showShop = _previewLoading || isManager;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/images/backgrounimg.jfif',
            fit: BoxFit.cover,
          ),
          // Dark overlay 60-65% keeps the showroom visible.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF050505).withValues(alpha: 0.72),
                  const Color(0xFF050505).withValues(alpha: 0.6),
                  const Color(0xFF050505).withValues(alpha: 0.7),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
          const _GoldParticles(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---- Hero: logo + tagline + golden divider ----
                      FadeTransition(
                        opacity: _logoFade,
                        child: Image.asset(
                          'lib/images/hayatlogo.png',
                          height: 210,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeTransition(
                        opacity: _taglineFade,
                        child: Text(
                          'Premium Carpets & Qaleen',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 3,
                            color: _goldLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeTransition(
                        opacity: _dividerFade,
                        child: const _CurvedDivider(),
                      ),
                      const SizedBox(height: 22),
                      // ---- Login glass card ----
                      SlideTransition(
                        position: _cardSlide,
                        child: FadeTransition(
                          opacity: _cardFade,
                          child: _buildGlassCard(loading, showShop, isManager),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- hero --

  Widget _buildGlassCard(bool loading, bool showShop, bool isManager) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: _gold.withValues(alpha: 0.18),
            blurRadius: 26,
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0x59000000), // rgba(0,0,0,0.35)
              border: Border.all(
                color: _gold.withValues(alpha: 0.5),
                width: 1.1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_goldLight, _gold, _goldDark],
                  ).createShader(rect),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to manage your business',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 26),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _gold,
                        validator: Validators.emailOrPhone,
                        decoration: _luxeDecoration(
                          'Email / Phone Number',
                          Icons.alternate_email,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (showShop)
                        _ShopDropdown(
                          loading: _previewLoading,
                          shops: _preview?.shops ?? const [],
                          value: _selectedShopId,
                          enabled: _previewLoading == false &&
                              (_preview?.shops.isNotEmpty ?? false),
                          onChanged: (v) => setState(() => _selectedShopId = v),
                        )
                      else
                        const SizedBox.shrink(),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _gold,
                        validator: (v) =>
                            Validators.required(v, 'Password is required'),
                        decoration: _luxeDecoration(
                          'Password',
                          Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: _gold,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RememberMe(
                        checked: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v),
                      ),
                      const SizedBox(height: 18),
                      _GoldButton(
                        loading: loading,
                        onPressed: _submit,
                      ),
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

  InputDecoration _luxeDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: _gold.withValues(alpha: 0.4),
        width: 1,
      ),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _gold, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.65),
      ),
      floatingLabelStyle: const TextStyle(
        color: _gold,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      errorStyle: const TextStyle(color: AppColors.premiumRedLight),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: _gold.withValues(alpha: 0.95),
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.premiumRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            const BorderSide(color: AppColors.premiumRedLight, width: 1.4),
      ),
    );
  }
}

// ---------------------------------------------------------------- widgets --

/// Repeating floating gold particles drifting upward.
class _GoldParticles extends StatefulWidget {
  const _GoldParticles();

  @override
  State<_GoldParticles> createState() => _GoldParticlesState();
}

class _GoldParticlesState extends State<_GoldParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  static const _count = 16;
  late final List<_Particle> _particles = List.generate(_count, (i) {
    final r = Random();
    return _Particle(
      x: r.nextDouble(),
      startY: r.nextDouble(),
      size: 2 + r.nextDouble() * 4,
      speed: 0.3 + r.nextDouble() * 0.7,
      opacity: 0.25 + r.nextDouble() * 0.45,
      sway: r.nextDouble() * 20,
      phase: r.nextDouble() * 2 * pi,
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              return Stack(
                children: [
                  for (final p in _particles)
                    Positioned(
                      left: p.x * w + sin(2 * pi * t + p.phase) * p.sway,
                      top: ((p.startY - p.speed * t) % 1.0) * h,
                      child: Opacity(
                        opacity: p.opacity * _edgeFade(p, t),
                        child: Container(
                          width: p.size,
                          height: p.size,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  double _edgeFade(_Particle p, double t) {
    final y = (p.startY - p.speed * t) % 1.0;
    final mid = 1 - (y - 0.5).abs() * 2;
    return mid.clamp(0.0, 1.0);
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.startY,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.sway,
    required this.phase,
  });

  final double x;
  final double startY;
  final double size;
  final double speed;
  final double opacity;
  final double sway;
  final double phase;
}

/// Elegant curved golden divider between the hero and login sections.
class _CurvedDivider extends StatelessWidget {
  const _CurvedDivider();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 28),
      painter: const _CurvedDividerPainter(),
    );
  }
}

class _CurvedDividerPainter extends CustomPainter {
  const _CurvedDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, size.height / 2);

    final path = Path()
      ..moveTo(0, center.dy + 4)
      ..quadraticBezierTo(center.dx, center.dy - 7, w, center.dy + 4);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0x00D4AF37), Color(0xFFD4AF37), Color(0xFFF7D488), Color(0xFFD4AF37), Color(0x00D4AF37)],
        stops: [0, 0.2, 0.5, 0.8, 1],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);

    final diamond = Path()
      ..moveTo(center.dx, center.dy - 2)
      ..lineTo(center.dx + 5, center.dy + 3)
      ..lineTo(center.dx, center.dy + 8)
      ..lineTo(center.dx - 5, center.dy + 3)
      ..close();
    canvas.drawPath(diamond, Paint()..color = const Color(0xFFD4AF37));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Large gold-gradient Sign In button with pulsing glow + press animation.
class _GoldButton extends StatefulWidget {
  const _GoldButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  State<_GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<_GoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  bool _pressed = false;

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.loading ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedBuilder(
          animation: _glow,
          builder: (context, _) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7D488), Color(0xFFD4AF37), Color(0xFFB8860B)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37)
                      .withValues(alpha: 0.28 + 0.32 * _glow.value),
                  blurRadius: 30,
                  spreadRadius: 1,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                child: widget.loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black87,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.login, size: 20, color: Colors.black87),
                          const SizedBox(width: 10),
                          Text(
                            'Sign In',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopDropdown extends StatelessWidget {
  const _ShopDropdown({
    required this.loading,
    required this.shops,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool loading;
  final List<ShopOption> shops;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  static const _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: _gold.withValues(alpha: 0.4), width: 1),
    );
    final decoration = InputDecoration(
      labelText: 'Branch',
      prefixIcon: const Icon(Icons.store_outlined, color: _gold, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
      floatingLabelStyle: const TextStyle(color: _gold, fontWeight: FontWeight.w600),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _gold.withValues(alpha: 0.95), width: 1.6),
      ),
    );

    if (loading) {
      return InputDecorator(
        decoration: decoration,
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
            ),
            const SizedBox(width: 12),
            Text(
              'Checking your branch...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey(shops.map((s) => s.id).join(',')),
      initialValue: shops.any((s) => s.id == value) ? value : null,
      dropdownColor: const Color(0xF0111111),
      icon: const Icon(Icons.arrow_drop_down, color: _gold),
      borderRadius: BorderRadius.circular(16),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: decoration,
      items: shops
          .map(
            (s) => DropdownMenuItem(
              value: s.id,
              child: Text(
                s.name,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
          .toList(),
      onChanged: enabled ? (v) => onChanged(v) : null,
    );
  }
}

class _RememberMe extends StatelessWidget {
  const _RememberMe({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  static const _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: checked
                    ? const LinearGradient(
                        colors: [_gold, Color(0xFFB8860B)],
                      )
                    : null,
                border: Border.all(
                  color: checked ? _gold : Colors.white.withValues(alpha: 0.35),
                  width: 1.4,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 15, color: Colors.black87)
                  : null,
            ),
            const SizedBox(width: 9),
            Text(
              'Remember me',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
