import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/activity_timeline.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/lux_widgets.dart';
import '../../customers/presentation/customer_detail_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../sales/presentation/sales_list_screen.dart';
import '../../suppliers/presentation/suppliers_screen.dart';
import '../models/dashboard_data.dart';
import '../providers/dashboard_providers.dart';
import 'branch_customers_screen.dart';
import 'branch_products_screen.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF7D488);
const _goldDark = Color(0xFFB8860B);
const _bg = Color(0xFF0B0B0F);

class ShopDetailScreen extends ConsumerWidget {
  const ShopDetailScreen({
    super.key,
    required this.shopId,
    this.shopName,
    this.manager,
    this.revenue,
    this.profit,
    this.saleCount,
  });

  final String shopId;
  final String? shopName;
  final String? manager;
  final double? revenue;
  final double? profit;
  final int? saleCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shopDetailProvider(shopId));
    final overviewAsync = ref.watch(shopOverviewProvider(shopId));

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ShowroomBackground(),
          SafeArea(
            child: async.when(
              loading: () => const LuxLoadingView(message: 'Loading branch...'),
              error: (e, st) => LuxErrorView(
                message: e.toString(),
                onRetry: () => ref.refresh(shopDetailProvider(shopId)),
              ),
              data: (data) {
                final name = shopName ?? 'Shop';
                return RefreshIndicator(
                  color: _gold,
                  backgroundColor: const Color(0xFF16141B),
                  onRefresh: () async {
                    ref.invalidate(shopDetailProvider(shopId));
                    ref.invalidate(shopOverviewProvider(shopId));
                    await Future.wait([
                      ref.read(shopDetailProvider(shopId).future),
                      ref.read(shopOverviewProvider(shopId).future),
                    ]);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                    children: [
                      _ShopTopBar(
                        onRefresh: () {
                          ref.invalidate(shopDetailProvider(shopId));
                          ref.invalidate(shopOverviewProvider(shopId));
                        },
                      ),
                      const SizedBox(height: 16),
                      _OverviewHeader(
                        overviewAsync: overviewAsync,
                        shopId: shopId,
                      ),
                      _ShopTitle(
                        name: name,
                        manager: manager,
                        address: overviewAsync.value?.shop.address,
                      ),
                      const SizedBox(height: 18),
                      _ShopMetricsRow(
                        revenue: revenue ?? data.cards.monthlyRevenue,
                        profit: profit ?? data.cards.monthlyProfit,
                        saleCount: saleCount ?? data.cards.salesTodayCount,
                      ),
                      const SizedBox(height: 26),
                      const LuxSectionTitle(
                        title: 'Overview',
                        subtitle: 'Key metrics for this branch',
                      ),
                      const SizedBox(height: 12),
                      _BuildOverviewGrid(
                        data: data,
                        overviewAsync: overviewAsync,
                      ),
                      const SizedBox(height: 26),
                      const LuxSectionTitle(
                        title: 'Branch Features',
                        subtitle: 'Open a module for this branch',
                      ),
                      const SizedBox(height: 12),
                      _BranchFeatureSlider(shopId: shopId, title: name),
                      if (overviewAsync.value?.managers.isNotEmpty ??
                          false) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Branch Team',
                          subtitle: 'Account managers assigned here',
                        ),
                        const SizedBox(height: 12),
                        _ManagersCard(managers: overviewAsync.value!.managers),
                      ],
                      if (overviewAsync.value?.customers.isNotEmpty ??
                          false) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Customers',
                          subtitle: 'Top dues holders at this branch',
                        ),
                        const SizedBox(height: 12),
                        _BuildCustomersCard(
                          overview: overviewAsync.value!,
                          shopId: shopId,
                          onSeeAll: () => _open(
                            context,
                            BranchCustomersScreen(shopId: shopId, title: name),
                          ),
                          onRetry: () =>
                              ref.refresh(shopOverviewProvider(shopId)),
                        ),
                      ],
                      if (overviewAsync.value?.products.isNotEmpty ??
                          false) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Products',
                          subtitle: 'Stock held at this branch',
                        ),
                        const SizedBox(height: 12),
                        _BuildProductsCard(
                          overview: overviewAsync.value!,
                          shopId: shopId,
                          onSeeAll: () => _open(
                            context,
                            BranchProductsScreen(shopId: shopId, title: name),
                          ),
                          onRetry: () =>
                              ref.refresh(shopOverviewProvider(shopId)),
                        ),
                      ],
                      if (overviewAsync.value?.lowStock.isNotEmpty ??
                          false) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Low Stock',
                          subtitle: 'Needs immediate restock',
                        ),
                        const SizedBox(height: 12),
                        _LowStockCard(items: overviewAsync.value!.lowStock),
                      ],
                      if (overviewAsync.value?.recentSales.isNotEmpty ??
                          false) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Recent Sales',
                          subtitle: 'Latest transactions at this branch',
                        ),
                        const SizedBox(height: 12),
                        _RecentSalesCard(
                          sales: overviewAsync.value!.recentSales,
                        ),
                      ],
                      if (overviewAsync.value?.recentExpenses.isNotEmpty ??
                          false) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Recent Expenses',
                          subtitle: 'Latest branch spend',
                        ),
                        const SizedBox(height: 12),
                        _RecentExpensesCard(
                          expenses: overviewAsync.value!.recentExpenses,
                        ),
                      ],
                      if (data.daily.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Daily Sales',
                          subtitle: 'Last 14 days',
                        ),
                        const SizedBox(height: 12),
                        LuxGlassCard(
                          child: SizedBox(
                            height: 200,
                            child: LineSalesChart(
                              points: data.daily,
                              lineColor: _gold,
                              expenseColor: AppColors.premiumRedLight,
                            ),
                          ),
                        ),
                      ],
                      if (data.monthly.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Monthly Revenue & Profit',
                          subtitle: 'Last 12 months',
                        ),
                        const SizedBox(height: 12),
                        LuxGlassCard(
                          child: SizedBox(
                            height: 200,
                            child: LineSalesChart(
                              points: data.monthly,
                              showExpenses: false,
                              lineColor: _gold,
                            ),
                          ),
                        ),
                      ],
                      if (data.expenseBreakdown.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Expense Breakdown',
                          subtitle: 'Last 30 days',
                        ),
                        const SizedBox(height: 12),
                        LuxGlassCard(
                          child: SizedBox(
                            height: 220,
                            child: PieChartWidget(
                              sections: data.expenseBreakdown
                                  .map(
                                    (e) => (label: e.category, value: e.total),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                      if (data.topProducts.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Top Products',
                          subtitle: 'Best sellers in this branch',
                        ),
                        const SizedBox(height: 12),
                        _TopProductsCard(products: data.topProducts),
                      ],
                      if (data.recentActivity.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Recent Activity',
                          subtitle: 'Latest changes in this branch',
                        ),
                        const SizedBox(height: 12),
                        LuxGlassCard(
                          child: ActivityTimeline(items: data.recentActivity),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _open(BuildContext context, Widget screen) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => screen));
  }
}

// ---------------------------------- helpers ---------------------------------

String _unitOf(String productType) {
  if (productType == 'carpet') return 'sqft';
  if (productType == 'meter') return 'm';
  return 'pcs';
}

class _BranchFeatureSlider extends StatelessWidget {
  const _BranchFeatureSlider({required this.shopId, required this.title});

  final String shopId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final features = <_BranchFeature>[
      _BranchFeature(
        label: 'Total Sales',
        icon: Icons.point_of_sale_outlined,
        gradient: const [Color(0xFF3B2A10), Color(0xFF6B4E1B)],
        screen: SalesListScreen(),
      ),
      _BranchFeature(
        label: 'Inventory',
        icon: Icons.inventory_2_outlined,
        gradient: const [Color(0xFF0F3D2E), Color(0xFF1F6E54)],
        screen: InventoryScreen(),
      ),
      _BranchFeature(
        label: 'Customers',
        icon: Icons.people_outline,
        gradient: const [Color(0xFF1B2A4A), Color(0xFF2F4F8F)],
        screen: BranchCustomersScreen(shopId: shopId, title: title),
      ),
      _BranchFeature(
        label: 'Suppliers',
        icon: Icons.local_shipping_outlined,
        gradient: const [Color(0xFF3A1B2A), Color(0xFF6E2F4F)],
        screen: SuppliersScreen(),
      ),
      _BranchFeature(
        label: 'Products',
        icon: Icons.shopping_bag_outlined,
        gradient: const [Color(0xFF26103A), Color(0xFF4F2F6E)],
        screen: BranchProductsScreen(shopId: shopId, title: title),
      ),
    ];

    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: features.length,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final feature = features[i];
          return _BranchFeatureButton(
            feature: feature,
            onTap: () => _openFeature(context, feature.screen),
          );
        },
      ),
    );
  }

  static void _openFeature(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _BranchFeature {
  const _BranchFeature({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final List<Color> gradient;
  final Widget screen;
}

class _BranchFeatureButton extends StatelessWidget {
  const _BranchFeatureButton({required this.feature, required this.onTap});

  final _BranchFeature feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = feature.gradient.last;
    return SizedBox(
      width: 128,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.04),
                        accent.withValues(alpha: 0.14),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              feature.icon,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock,
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        feature.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Open',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.65),
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
    );
  }
}

String _typeLabel(String productType) {
  if (productType == 'carpet') return 'Carpet';
  if (productType == 'meter') return 'Meter';
  return 'Qaleen';
}

class _OverviewHeader extends ConsumerWidget {
  const _OverviewHeader({required this.overviewAsync, required this.shopId});

  final AsyncValue<ShopOverview> overviewAsync;
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return overviewAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: LuxGlassCard(
          child: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.danger,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Branch summary unavailable: $e',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.refresh(shopOverviewProvider(shopId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (_) => const SizedBox.shrink(),
    );
  }
}

class _BuildOverviewGrid extends StatelessWidget {
  const _BuildOverviewGrid({required this.data, required this.overviewAsync});

  final DashboardData data;
  final AsyncValue<ShopOverview> overviewAsync;

  @override
  Widget build(BuildContext context) {
    final overview = overviewAsync.value;
    final stats = <Widget>[
      _ShopStatTile(
        icon: Icons.point_of_sale_rounded,
        title: 'Sales Today',
        value: data.cards.salesToday,
        subtitle: '${data.cards.salesTodayCount} transactions',
      ),
      _ShopStatTile(
        icon: Icons.payments_outlined,
        title: 'Monthly Revenue',
        value: data.cards.monthlyRevenue,
        subtitle: 'Profit ${Formatters.compact(data.cards.monthlyProfit)}',
      ),
      _ShopStatTile(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Monthly Expenses',
        value: data.cards.monthlyExpenses,
      ),
      _ShopStatTile(
        icon: Icons.inventory_2_outlined,
        title: 'Total Products',
        value: overview?.cards.totalProducts ?? data.cards.totalProducts,
        number: true,
        subtitle:
            (overview?.cards.lowStockCount ?? data.cards.lowStockCount) > 0
            ? '${overview?.cards.lowStockCount ?? data.cards.lowStockCount} low on stock'
            : 'fully stocked',
      ),
      _ShopStatTile(
        icon: Icons.savings_outlined,
        title: 'Stock Value',
        value: overview?.cards.totalStockValue ?? data.cards.totalStockValue,
      ),
      _ShopStatTile(
        icon: Icons.people_alt_outlined,
        title: 'Customers',
        value: overview?.cards.customerCount ?? 0,
        number: true,
        subtitle: 'Enrolled at this branch',
      ),
      _ShopStatTile(
        icon: Icons.local_shipping_outlined,
        title: 'Suppliers',
        value: overview?.cards.supplierCount ?? 0,
        number: true,
        subtitle: 'Linked to this branch',
      ),
      _ShopStatTile(
        icon: Icons.receipt_long_outlined,
        title: 'Receivables',
        value: overview?.cards.receivables ?? 0,
        subtitle: 'Total customer dues',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats.map((w) => SizedBox(width: width, child: w)).toList(),
        );
      },
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.label,
    this.onSeeAll,
    this.seeAllCount,
    this.icon,
  });

  final String label;
  final VoidCallback? onSeeAll;
  final int? seeAllCount;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: _goldLight),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: _goldLight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              seeAllCount != null ? 'See all ($seeAllCount)' : 'See all',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _ManagersCard extends StatelessWidget {
  const _ManagersCard({required this.managers});

  final List<OverviewManager> managers;

  @override
  Widget build(BuildContext context) {
    return LuxGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: managers.map((m) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_goldLight, _gold, _goldDark],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    m.name.isEmpty ? '?' : m.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17151C),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name.isEmpty ? 'Unassigned' : m.name,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (m.email.isNotEmpty || m.phone.isNotEmpty)
                        Text(
                          [
                            m.email,
                            m.phone,
                          ].where((e) => e.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BuildCustomersCard extends ConsumerWidget {
  const _BuildCustomersCard({
    required this.overview,
    required this.shopId,
    required this.onSeeAll,
    required this.onRetry,
  });

  final ShopOverview overview;
  final String shopId;
  final VoidCallback onSeeAll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LuxGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _CardHeader(
            label: 'Top dues holders',
            icon: Icons.people_alt_outlined,
            seeAllCount: overview.cards.customerCount,
            onSeeAll: onSeeAll,
          ),
          const Divider(color: Colors.white12, height: 16),
          ...overview.customers.map((c) => _CustomerRow(customer: c)),
          if (overview.customers.isEmpty)
            Center(
              child: Text(
                'No customers yet',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer});

  final OverviewCustomer customer;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerDetailScreen(customerId: customer.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _goldLight,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    [
                      if (customer.phone.isNotEmpty) customer.phone,
                      '${customer.purchaseCount} purchases · ${Formatters.compact(customer.totalSpent)} spent',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (customer.balance > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'Due ${Formatters.compact(customer.balance)}',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Clear',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6FBF6F),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BuildProductsCard extends ConsumerWidget {
  const _BuildProductsCard({
    required this.overview,
    required this.shopId,
    required this.onSeeAll,
    required this.onRetry,
  });

  final ShopOverview overview;
  final String shopId;
  final VoidCallback onSeeAll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LuxGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _CardHeader(
            label: 'Stock by value',
            icon: Icons.inventory_2_outlined,
            seeAllCount: overview.cards.totalProducts,
            onSeeAll: onSeeAll,
          ),
          const Divider(color: Colors.white12, height: 16),
          ...overview.products.map((p) => _ProductRow(product: p)),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});

  final OverviewProduct product;

  @override
  Widget build(BuildContext context) {
    final unit = _unitOf(product.productType);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              product.productType == 'carpet'
                  ? Icons.grid_on
                  : product.productType == 'meter'
                  ? Icons.straighten
                  : Icons.inventory_2_outlined,
              size: 16,
              color: _goldLight,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (product.isLowStock) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'LOW',
                          style: GoogleFonts.poppins(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${_typeLabel(product.productType)}${product.sku.isNotEmpty ? ' · ${product.sku}' : ''} · ${product.quantity.round()} $unit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Formatters.compact(product.stockValue),
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _goldLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.items});

  final List<LowStockProduct> items;

  @override
  Widget build(BuildContext context) {
    return LuxGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: items.map((p) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Only ${p.quantity.round()} left (threshold ${p.lowStockThreshold.round()})',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${p.quantity.round()} ${p.quantity.round() <= 1 ? 'unit' : 'units'}',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentSalesCard extends StatelessWidget {
  const _RecentSalesCard({required this.sales});

  final List<OverviewSale> sales;

  @override
  Widget build(BuildContext context) {
    return LuxGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: sales.map((s) {
          final due = s.dueAmount > 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    s.invoiceNo.length > 6
                        ? '…${s.invoiceNo.substring(s.invoiceNo.length - 4)}'
                        : s.invoiceNo,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _goldLight,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${s.invoiceNo} · ${Formatters.dateTime(s.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.compact(s.totalAmount),
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _goldLight,
                      ),
                    ),
                    Text(
                      due ? 'Due ${Formatters.compact(s.dueAmount)}' : 'Paid',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: due ? AppColors.danger : const Color(0xFF6FBF6F),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentExpensesCard extends StatelessWidget {
  const _RecentExpensesCard({required this.expenses});

  final List<OverviewExpense> expenses;

  @override
  Widget build(BuildContext context) {
    return LuxGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: expenses.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    e.category == 'rent'
                        ? Icons.home_work_outlined
                        : e.category == 'electricity'
                        ? Icons.bolt_outlined
                        : e.category == 'salary'
                        ? Icons.payments_outlined
                        : e.category == 'fuel'
                        ? Icons.local_gas_station_outlined
                        : Icons.receipt_long_outlined,
                    size: 16,
                    color: _goldLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _typeTitle(e.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        [
                          Formatters.date(e.date),
                          if (e.description.isNotEmpty) e.description,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.compact(e.amount),
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _goldLight,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _typeTitle(String category) {
    switch (category) {
      case 'rent':
        return 'Rent';
      case 'electricity':
        return 'Electricity';
      case 'salary':
        return 'Salary';
      case 'fuel':
        return 'Fuel';
      case 'internet':
        return 'Internet';
      case 'maintenance':
        return 'Maintenance';
      case 'marketing':
        return 'Marketing';
      default:
        return 'Other';
    }
  }
}

class _ShopTopBar extends StatelessWidget {
  const _ShopTopBar({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: _goldLight,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'lib/images/hayatlogo.png',
            width: 38,
            height: 38,
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
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                  color: _gold,
                ),
              ),
              Text(
                'BRANCH COMMAND CENTER',
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  letterSpacing: 1.6,
                  color: Colors.white.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: Icon(
            Icons.refresh_rounded,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _ShopTitle extends StatelessWidget {
  const _ShopTitle({required this.name, this.manager, this.address});

  final String name;
  final String? manager;
  final String? address;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LuxGoldGradientText(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        if ((manager != null && manager!.isNotEmpty) ||
            (address != null && address!.isNotEmpty)) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (manager != null && manager!.isNotEmpty)
                'Manager  ·  $manager',
              if (address != null && address!.isNotEmpty) address,
            ].join('   ·   '),
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
        const SizedBox(height: 14),
        const LuxGoldDivider(),
      ],
    );
  }
}

class _ShopMetricsRow extends StatelessWidget {
  const _ShopMetricsRow({
    required this.revenue,
    required this.profit,
    required this.saleCount,
  });

  final double revenue;
  final double profit;
  final int saleCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'REVENUE',
            value: Formatters.compact(revenue),
            glow: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            label: 'PROFIT',
            value: Formatters.compact(profit),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(label: 'SALES', value: '$saleCount'),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.glow = false,
  });

  final String label;
  final String value;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return LuxGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      glow: glow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 8.5,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _goldLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopStatTile extends StatelessWidget {
  const _ShopStatTile({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.number = false,
  });

  final IconData icon;
  final String title;
  final num value;
  final String? subtitle;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return LuxGlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_goldLight, _gold, _goldDark],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.32),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, size: 19, color: const Color(0xFF17151C)),
          ),
          const SizedBox(height: 12),
          LuxGoldGradientText(
            child: LuxAnimatedNumber(
              value: value,
              currency: !number,
              style: GoogleFonts.playfairDisplay(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: _goldLight.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.products});

  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    return LuxGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: products.indexed.map((e) {
          final product = e.$2;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_goldLight, _gold, _goldDark],
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${e.$1 + 1}',
                    style: const TextStyle(
                      color: Color(0xFF17151C),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${product.quantity} sold',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Formatters.compact(product.revenue),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _goldLight,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
