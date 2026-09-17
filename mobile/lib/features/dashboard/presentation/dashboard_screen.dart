import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/carpet_pattern.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../categories/presentation/category_screen.dart';
import '../../expenses/presentation/expense_form_screen.dart';
import '../../inventory/presentation/stock_screens.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../products/presentation/product_form_screen.dart';
import '../../products/presentation/product_list_screen.dart';
import '../../sales/presentation/sale_form_screen.dart';
import '../../settings/presentation/profile_screen.dart';
import '../models/dashboard_data.dart';
import '../providers/dashboard_providers.dart';
import 'shop_detail_screen.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF7D488);
const _goldDark = Color(0xFFB8860B);
const _bg = Color(0xFF0B0B0F);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.onOpenDrawer});

  /// Opens the app sidebar (drawer) from the HomeShell scaffold.
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(dashboardControllerProvider);
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _DashboardBackground(),
          SafeArea(
            child: state.data.when(
              loading: () => const _LoadingView(),
              error: (e, st) => _ErrorView(
                message: e.toString(),
                onRetry: () =>
                    ref.read(dashboardControllerProvider.notifier).refresh(),
              ),
              data: (data) => RefreshIndicator(
                color: _gold,
                backgroundColor: const Color(0xFF16141B),
                onRefresh: () =>
                    ref.read(dashboardControllerProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 150),
                  children: isAdmin
                      ? _buildAdminChildren(context, ref, data, user)
                      : _buildManagerChildren(context, data, user),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openShop(BuildContext context, ShopComparison shop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(
          shopId: shop.shopId,
          shopName: shop.shopName,
          manager: shop.manager,
          revenue: shop.sales,
          profit: shop.profit,
          saleCount: shop.saleCount,
        ),
      ),
    );
  }

  void _openLowStock(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LowStockScreen()),
    );
  }

  // ---------------------------------------------------------- admin layout --

  List<Widget> _buildAdminChildren(
      BuildContext context, WidgetRef ref, DashboardData data, User? user) {
    return [
      _LuxHeader(user: user, isAdmin: true, onOpenDrawer: onOpenDrawer),
      const SizedBox(height: 24),
      if (data.comparison.isEmpty)
        _RevenueCard(data: data)
      else
        _BranchSlider(branches: data.comparison, onOpen: (c) => _openShop(context, c)),
      if (data.comparison.isNotEmpty) ...[
        const SizedBox(height: 26),
        const _SectionTitle(
          title: 'Branches',
          subtitle: 'Tap a branch to open its dashboard',
        ),
        const SizedBox(height: 12),
        for (final branch in data.comparison)
          _BranchQuickCard(
            branch: branch,
            onOpen: () => _openShop(context, branch),
          ),
      ],
    ];
  }

  // ------------------------------------------------------- manager layout --

  List<Widget> _buildManagerChildren(BuildContext context, DashboardData data, User? user) {
    return [
      _LuxHeader(user: user, isAdmin: false, onOpenDrawer: onOpenDrawer),
      const SizedBox(height: 24),
      _OverviewSlider(cards: data.cards),
      const SizedBox(height: 22),
      _StockActionRow(),
      const SizedBox(height: 28),
      _SectionTitle(
        title: 'Low Stock Alerts',
        subtitle: data.lowStock.isEmpty
            ? 'All products are well stocked'
            : '${data.lowStock.length} product${data.lowStock.length == 1 ? '' : 's'} need attention',
        actionLabel: data.lowStock.isEmpty ? null : 'View All',
        action: data.lowStock.isEmpty ? null : () => _openLowStock(context),
      ),
      const SizedBox(height: 12),
      _LowStockCard(items: data.lowStock),
      const SizedBox(height: 28),
      const _SectionTitle(
        title: 'Quick Actions',
        subtitle: 'Frequent tasks at your fingertips',
      ),
      const SizedBox(height: 12),
      const _QuickActionsSlider(),
      if (data.products.isNotEmpty) ...[
        const SizedBox(height: 28),
        _SectionTitle(
          title: 'Products',
          subtitle: '${data.products.length} product${data.products.length == 1 ? '' : 's'} · stock by colour',
        ),
        const SizedBox(height: 12),
        _ProductTreeCard(items: data.products),
      ],
    ];
  }
}

// ---------------------------------------------------------------- backdrop --

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'lib/images/admin_dashboard.jfif',
          fit: BoxFit.cover,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x50050505),
                Color(0x99050505),
                Color(0xB8050505),
              ],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -90,
          child: _Glow(size: 280, color: _gold.withValues(alpha: 0.10)),
        ),
        Positioned(
          top: 430,
          left: -120,
          child: _Glow(size: 320, color: _goldDark.withValues(alpha: 0.09)),
        ),
        Positioned(
          bottom: 60,
          right: -120,
          child: _Glow(size: 300, color: const Color(0xFF3A2E10).withValues(alpha: 0.28)),
        ),
        const CarpetPattern(opacity: 0.05),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ header --

class _LuxHeader extends ConsumerWidget {
  const _LuxHeader({required this.user, required this.isAdmin, this.onOpenDrawer});

  final User? user;
  final bool isAdmin;
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = (user?.name ?? '').split(' ').first;
    final scope = isAdmin ? 'Muallim HQ' : (user?.assignedShopName ?? 'Manager');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'lib/images/muallimlogo.png',
                width: 42,
                height: 42,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MUALLIM CARPETS',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                      color: _gold,
                    ),
                  ),
                  Text(
                    'PREMIUM CARPET & QALEEN',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      letterSpacing: 1.6,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            const _LuxBell(),
            const SizedBox(width: 6),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                final open = onOpenDrawer;
                if (open != null) {
                  open();
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                }
              },
              child: _Avatar(initial: (user?.name ?? 'M').characters.first),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          _greeting().toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w600,
            color: _goldLight.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 2),
        _GoldGradientText(
          child: Text(
            firstName.isEmpty ? 'Welcome' : firstName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              '${user?.name ?? 'User'}  ·  $scope',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _GoldDivider(),
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.6),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_goldLight, _gold, _goldDark],
        ),
        boxShadow: [
          BoxShadow(color: Color(0x66D4AF37), blurRadius: 14, spreadRadius: -2),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF17151C),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initial.toUpperCase(),
          style: GoogleFonts.playfairDisplay(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: _goldLight,
          ),
        ),
      ),
    );
  }
}

class _LuxBell extends ConsumerWidget {
  const _LuxBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          icon: Icon(
            Icons.notifications_none_rounded,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
        if (unread > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_goldLight, _gold, _goldDark],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF17151C),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(double.infinity, 14),
      painter: _GoldDividerPainter(),
    );
  }
}

class _GoldDividerPainter extends CustomPainter {
  const _GoldDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final line = Paint()
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        colors: [
          _gold.withValues(alpha: 0),
          _gold.withValues(alpha: 0.75),
          _gold.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawLine(Offset(0, midY), Offset(size.width * 0.42, midY), line);
    canvas.drawLine(
        Offset(size.width * 0.58, midY), Offset(size.width, midY), line);

    final diamond = Paint()..color = _goldLight;
    final center = Offset(size.width / 2, midY);
    final s = 5.0;
    final path = Path()
      ..moveTo(center.dx, center.dy - s)
      ..lineTo(center.dx + s * 0.7, center.dy)
      ..lineTo(center.dx, center.dy + s)
      ..lineTo(center.dx - s * 0.7, center.dy)
      ..close();
    canvas.drawPath(path, diamond);
  }

  @override
  bool shouldRepaint(_GoldDividerPainter oldDelegate) => false;
}

// --------------------------------------------------------------- revenue --

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final growth = _growthPercent(data);
    final spark = _sparkValues(data);

    return _GlassCard(
      padding: const EdgeInsets.all(20),
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'REVENUE OVERVIEW',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                  color: _goldLight.withValues(alpha: 0.9),
                ),
              ),
              const Spacer(),
              _GrowthBadge(growth: growth),
            ],
          ),
          const SizedBox(height: 12),
          _GoldGradientText(
            child: _AnimatedNumber(
              value: data.cards.monthlyRevenue,
              style: GoogleFonts.playfairDisplay(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                height: 1.05,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Monthly revenue  ·  ${Formatters.compact(data.cards.monthlyProfit)} profit',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _Sparkline(values: spark, height: 62),
          ),
        ],
      ),
    );
  }
}

class _GrowthBadge extends StatelessWidget {
  const _GrowthBadge({required this.growth});

  final double? growth;

  @override
  Widget build(BuildContext context) {
    if (growth == null) return const SizedBox.shrink();
    final up = growth! >= 0;
    final color = up ? _goldLight : AppColors.premiumRedLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${up ? '+' : ''}${growth!.toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.height});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(values: values, progress: t),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.progress});

  final List<double> values;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - 4 -
          (values[i] - minV) / range * (size.height - 8);
      pts.add(Offset(x, y));
    }

    final drawW = size.width * progress.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, drawW, size.height));

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: const [_goldLight, _gold, _goldDark],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final mid = Offset(
        (pts[i - 1].dx + pts[i].dx) / 2,
        (pts[i - 1].dy + pts[i].dy) / 2,
      );
      path.quadraticBezierTo(pts[i - 1].dx, pts[i - 1].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);

    final area = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _gold.withValues(alpha: 0.30),
            _gold.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(path, linePaint);

    canvas.drawCircle(
      pts.last,
      3.6,
      Paint()
        ..color = _goldLight
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.values != values;
}

// ------------------------------------------------------- overview slider --

class _OverviewSlider extends StatefulWidget {
  const _OverviewSlider({required this.cards});

  final DashboardCards cards;

  @override
  State<_OverviewSlider> createState() => _OverviewSliderState();
}

class _OverviewSliderState extends State<_OverviewSlider> {
  final _controller = PageController(viewportFraction: 0.84);
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<({IconData icon, String label, String subtitle, num value, bool currency, Color color, VoidCallback? onTap})>
      get _cards {
    final c = widget.cards;
    return [
      (
        icon: Icons.point_of_sale_rounded,
        label: 'Daily Sale',
        subtitle: "Today's revenue",
        value: c.salesToday,
        currency: true,
        color: _goldLight,
        onTap: null,
      ),
      (
        icon: Icons.inventory_2_outlined,
        label: 'Products',
        subtitle: 'Active in your branch',
        value: c.totalProducts,
        currency: false,
        color: const Color(0xFF7FB5E8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProductListScreen()),
        ),
      ),
      (
        icon: Icons.warning_amber_rounded,
        label: 'Stock Alerts',
        subtitle: 'Need restocking',
        value: c.lowStockCount,
        currency: false,
        color: AppColors.premiumRedLight,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LowStockScreen()),
        ),
      ),
      (
        icon: Icons.people_outline,
        label: 'Customers',
        subtitle: 'Served to date',
        value: c.customerCount,
        currency: false,
        color: const Color(0xFF6FBE8C),
        onTap: null,
      ),
      (
        icon: Icons.local_shipping_outlined,
        label: 'Suppliers',
        subtitle: 'Suppliers in branch',
        value: c.supplierCount,
        currency: false,
        color: const Color(0xFFC9A9FF),
        onTap: null,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _OverviewCard(
                icon: cards[index].icon,
                label: cards[index].label,
                subtitle: cards[index].subtitle,
                value: cards[index].value,
                currency: cards[index].currency,
                color: cards[index].color,
                onTap: cards[index].onTap,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            cards.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _current ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: i == _current
                    ? const LinearGradient(colors: [_goldLight, _gold, _goldDark])
                    : null,
                color: i == _current ? null : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    this.currency = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final num value;
  final Color color;
  final bool currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = _GlassCard(
      padding: const EdgeInsets.all(18),
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_goldLight, _gold, _goldDark],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF17151C)),
              ),
              const Spacer(),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 8),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          _GoldGradientText(
            child: _AnimatedNumber(
              value: value,
              currency: currency,
              style: GoogleFonts.playfairDisplay(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.05,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(24), onTap: onTap, child: card),
    );
  }
}

class _StockActionRow extends ConsumerWidget {
  const _StockActionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <({String label, IconData icon, Color color, Widget screen})>[
      (
        label: 'Stock In',
        icon: Icons.south_west_rounded,
        color: const Color(0xFF6FBE8C),
        screen: const StockInScreen(),
      ),
      (
        label: 'Stock Out',
        icon: Icons.north_east_rounded,
        color: AppColors.danger,
        screen: const StockOutScreen(),
      ),
      (
        label: 'Stock Transfer',
        icon: Icons.swap_horiz_rounded,
        color: _goldLight,
        screen: const StockTransferScreen(),
      ),
    ];
    return Row(
      children: actions
          .map(
            (a) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => a.screen))
                        .then((_) =>
                            ref.read(dashboardControllerProvider.notifier).refresh()),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: const Color(0x33000000),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _gold.withValues(alpha: 0.28)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: a.color.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                                border: Border.all(color: a.color.withValues(alpha: 0.5)),
                              ),
                              child: Icon(a.icon, size: 20, color: a.color),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              a.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ------------------------------------------------------------ low stock card --

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.items});

  final List<LowStockProduct> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _GlassCard(
        child: _EmptyNote('No low stock items — you are all stocked up!'),
      );
    }
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final item in items.take(6)) _LowStockRow(item: item),
          if (items.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${items.length - 6} more',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.item});

  final LowStockProduct item;

  @override
  Widget build(BuildContext context) {
    final pct = item.lowStockThreshold > 0
        ? (item.quantity / item.lowStockThreshold).clamp(0.0, 1.0)
        : 1.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.premiumRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.premiumRedLight.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.premiumRedLight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(AppColors.premiumRedLight),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${item.quantity.round()} left',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.premiumRedLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ product tree --

class _ProductTreeCard extends StatelessWidget {
  const _ProductTreeCard({required this.items});

  final List<DashboardProduct> items;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: items.isEmpty
          ? const _EmptyNote('No products yet')
          : Column(
              children: items
                  .take(10)
                  .map((p) => _ProductTreeTile(product: p))
                  .toList(),
            ),
    );
  }
}

class _ProductTreeTile extends StatelessWidget {
  const _ProductTreeTile({required this.product});

  final DashboardProduct product;

  @override
  Widget build(BuildContext context) {
    final colors = product.colorStocks;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductThumb(image: product.image),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.code.isEmpty ? product.name : product.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _goldLight,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (product.code.isNotEmpty && product.name.isNotEmpty)
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    if (product.size.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const _TreeJoint(),
                          const SizedBox(width: 8),
                          Text(
                            'Size: ${product.size}',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StockPill(quantity: product.quantity, low: product.isLowStock),
            ],
          ),
          if (colors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 6),
            for (final c in colors) _TreeColorRow(stock: c),
          ],
        ],
      ),
    );
  }
}

class _TreeColorRow extends StatelessWidget {
  const _TreeColorRow({required this.stock});

  final DashboardColorStock stock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        children: [
          const _TreeJoint(),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _colorFromName(stock.color),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stock.color.isEmpty ? '—' : stock.color.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          _MiniStat(label: 'Sets', value: stock.sets),
          const SizedBox(width: 6),
          _MiniStat(label: 'Pieces', value: stock.pieces),
        ],
      ),
    );
  }
}

class _TreeJoint extends StatelessWidget {
  const _TreeJoint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: _gold.withValues(alpha: 0.45), width: 1.2),
          bottom: BorderSide(color: _gold.withValues(alpha: 0.45), width: 1.2),
        ),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6)),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gold.withValues(alpha: 0.25)),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            color: Colors.white.withValues(alpha: 0.65),
          ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: '$value',
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: _goldLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({required this.quantity, required this.low});

  final int quantity;
  final bool low;

  @override
  Widget build(BuildContext context) {
    final color = low ? const Color(0xFFFF6B6B) : const Color(0xFF4ADE80);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            '$quantity',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            'in stock',
            style: GoogleFonts.poppins(
              fontSize: 8,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.image});

  final String image;

  static const double _size = 56;

  static final Uint8List _transparentPixel = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withValues(alpha: 0.3)),
          ),
          child: Icon(
            Icons.chair_outlined,
            color: _gold.withValues(alpha: 0.7),
            size: _size * 0.46,
          ),
        );

    if (image.isEmpty) return fallback();
    ImageProvider provider;
    if (image.startsWith('data:image')) {
      try {
        provider = MemoryImage(base64.decode(image.split(',').last));
      } catch (_) {
        provider = MemoryImage(_transparentPixel);
      }
    } else {
      provider = NetworkImage(image);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image(
        image: provider,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback(),
      ),
    );
  }
}

Color _colorFromName(String name) {
  switch (name.trim().toLowerCase()) {
    case 'red':
      return const Color(0xFFE53935);
    case 'blue':
      return const Color(0xFF1E88E5);
    case 'green':
      return const Color(0xFF43A047);
    case 'yellow':
      return const Color(0xFFFDD835);
    case 'orange':
      return const Color(0xFFFB8C00);
    case 'purple':
      return const Color(0xFF8E24AA);
    case 'pink':
      return const Color(0xFFEC407A);
    case 'brown':
      return const Color(0xFF8D6E63);
    case 'black':
      return const Color(0xFF212121);
    case 'white':
      return const Color(0xFFF5F5F5);
    case 'grey':
    case 'gray':
      return const Color(0xFF9E9E9E);
    case 'beige':
    case 'cream':
      return const Color(0xFFE8DCC0);
    case 'maroon':
      return const Color(0xFF800000);
    case 'navy':
      return const Color(0xFF1A237E);
    case 'gold':
      return _gold;
    default:
      return _gold;
  }
}

// --------------------------------------------------------------- branches --

class _BranchSlider extends StatefulWidget {
  const _BranchSlider({required this.branches, required this.onOpen});

  final List<ShopComparison> branches;
  final void Function(ShopComparison branch) onOpen;

  @override
  State<_BranchSlider> createState() => _BranchSliderState();
}

class _BranchSliderState extends State<_BranchSlider> {
  final _controller = PageController(viewportFraction: 0.88);
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 198,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.branches.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              final branch = widget.branches[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _BranchCard(
                  name: branch.shopName ?? 'Branch ${index + 1}',
                  manager: branch.manager,
                  revenue: branch.sales,
                  profit: branch.profit,
                  saleCount: branch.saleCount,
                  onOpen: () => widget.onOpen(branch),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.branches.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _current ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: i == _current
                    ? const LinearGradient(
                        colors: [_goldLight, _gold, _goldDark],
                      )
                    : null,
                color: i == _current
                    ? null
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.name,
    required this.revenue,
    required this.profit,
    required this.saleCount,
    this.manager,
    this.onOpen,
  });

  final String name;
  final String? manager;
  final double revenue;
  final double profit;
  final int saleCount;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_goldLight, _gold, _goldDark],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 18,
                  color: Color(0xFF17151C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (manager != null && manager!.isNotEmpty)
                      Text(
                        manager!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              const _StatusBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _BranchMetric(label: 'Revenue', value: Formatters.compact(revenue)),
              _BranchMetric(label: 'Profit', value: Formatters.compact(profit)),
              _BranchMetric(label: 'Sales', value: '$saleCount'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: onOpen,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_goldLight, _gold, _goldDark],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Open Branch',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: const Color(0xFF17151C),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: Color(0xFF17151C),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF3E8E5A).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3E8E5A).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFF6FBE8C),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6FBE8C).withValues(alpha: 0.7),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Open',
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6FBE8C),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchMetric extends StatelessWidget {
  const _BranchMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 9,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- branch list --

class _BranchQuickCard extends StatelessWidget {
  const _BranchQuickCard({required this.branch, required this.onOpen});

  final ShopComparison branch;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final name = branch.shopName ?? 'Branch';
    final manager = branch.manager ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _GlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_goldLight, _gold, _goldDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withValues(alpha: 0.32),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 22,
                      color: Color(0xFF17151C),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (manager.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            manager,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'REVENUE',
                        style: GoogleFonts.poppins(
                          fontSize: 8.5,
                          letterSpacing: 0.9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.compact(branch.sales),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _goldLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- quick actions --

class _QuickActionsSlider extends ConsumerWidget {
  const _QuickActionsSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <({IconData icon, String label, Color color, Widget screen})>[
      (
        icon: Icons.add_box_outlined,
        label: 'Add Product',
        color: const Color(0xFF7FB5E8),
        screen: const ProductFormScreen(),
      ),
      (
        icon: Icons.point_of_sale_rounded,
        label: 'New Sale',
        color: const Color(0xFF6FBE8C),
        screen: const SaleFormScreen(),
      ),
      (
        icon: Icons.add_card_outlined,
        label: 'Expense Entry',
        color: AppColors.premiumRedLight,
        screen: const ExpenseFormScreen(),
      ),
      (
        icon: Icons.warning_amber_rounded,
        label: 'Low Stock',
        color: _goldLight,
        screen: const LowStockScreen(),
      ),
      (
        icon: Icons.category_outlined,
        label: 'Categories',
        color: const Color(0xFFC9A96A),
        screen: const CategoryScreen(),
      ),
    ];

    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final a = actions[index];
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => a.screen))
                  .then((_) =>
                      ref.read(dashboardControllerProvider.notifier).refresh()),
              child: Ink(
                width: 138,
                decoration: BoxDecoration(
                  color: const Color(0x55000000),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _gold.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_goldLight, _gold, _goldDark],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _gold.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(a.icon, size: 18, color: const Color(0xFF17151C)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: a.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              a.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ common --

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: _gold.withValues(alpha: glow ? 0.22 : 0.10),
            blurRadius: glow ? 34 : 24,
            spreadRadius: glow ? -4 : -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _gold.withValues(alpha: glow ? 0.5 : 0.34),
                width: glow ? 1.2 : 1,
              ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.action,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null && actionLabel != null)
          TextButton(
            onPressed: action,
            style: TextButton.styleFrom(
              foregroundColor: _goldLight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              actionLabel!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedNumber extends StatelessWidget {
  const _AnimatedNumber({required this.value, required this.style, this.currency = true});

  final num value;
  final TextStyle style;
  final bool currency;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        currency ? Formatters.currency(v) : Formatters.number(v),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _GoldGradientText extends StatelessWidget {
  const _GoldGradientText({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_goldLight, _gold, _goldDark],
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              color: _gold,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your showroom...',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _gold, size: 42),
            const SizedBox(height: 14),
            Text(
              'Something went wrong',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _goldLight,
                side: const BorderSide(color: _gold),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              ),
              icon: const Icon(Icons.refresh, size: 17),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double? _growthPercent(DashboardData d) {
  final daily = d.daily.where((p) => p.sales > 0).toList();
  if (daily.length >= 4) {
    final half = daily.length ~/ 2;
    var prev = 0.0;
    var cur = 0.0;
    for (var i = 0; i < daily.length; i++) {
      if (i < half) {
        prev += daily[i].sales;
      } else {
        cur += daily[i].sales;
      }
    }
    if (prev <= 0) return cur > 0 ? null : 0;
    return (cur - prev) / prev * 100;
  }
  if (d.monthly.length >= 2) {
    final prev = d.monthly[d.monthly.length - 2].sales;
    final cur = d.monthly[d.monthly.length - 1].sales;
    if (prev <= 0) return cur > 0 ? null : 0;
    return (cur - prev) / prev * 100;
  }
  return null;
}

List<double> _sparkValues(DashboardData d) {
  final src = d.daily.isNotEmpty ? d.daily : d.monthly;
  final vals = src.map((p) => p.sales).toList();
  if (vals.length < 2) return [0, 0];
  return vals;
}
