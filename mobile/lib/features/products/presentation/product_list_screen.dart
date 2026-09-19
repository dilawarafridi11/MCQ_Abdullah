import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../../categories/providers/category_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../inventory/presentation/stock_screens.dart';
import '../models/product.dart';
import '../providers/product_providers.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productListControllerProvider);
    final categories = ref.watch(categoryListControllerProvider).data.value ?? const [];
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Low stock only',
            onPressed: () => ref.read(productListControllerProvider.notifier).setLowStockOnly(!state.lowStockOnly),
            icon: Icon(
              state.lowStockOnly ? Icons.warning_amber : Icons.warning_amber_outlined,
              color: state.lowStockOnly ? AppColors.danger : null,
            ),
          ),
          if (!isAdmin)
            IconButton(
              tooltip: 'Add Product',
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(productListControllerProvider.notifier).setSearch(v),
              decoration: InputDecoration(
                hintText: 'Search by name, SKU or barcode...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(productListControllerProvider.notifier).setSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: state.categoryId == null,
                    onSelected: (_) => ref.read(productListControllerProvider.notifier).setCategory(null),
                  ),
                ),
                ...categories.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(c.name),
                        selected: state.categoryId == c.id,
                        onSelected: (_) => ref.read(productListControllerProvider.notifier).setCategory(c.id),
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: state.data.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.read(productListControllerProvider.notifier).refresh(),
              ),
              data: (page) {
                if (page.products.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: state.lowStockOnly ? 'No low stock products' : 'No products found',
                    subtitle: state.lowStockOnly ? 'All products are well stocked.' : 'Add your first product to get started.',
                    action: state.lowStockOnly || isAdmin ? null : () => _openForm(context),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(productListControllerProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: page.products.length,
                    itemBuilder: (context, index) {
                      final product = page.products[index];
                      return _ProductCard(
                        product: product,
                        onTap: isAdmin ? null : () => _openDetail(context, product: product),
                        onEdit: () => _openForm(context, product: product),
                        onStockIn: () => _openStockIn(context, product),
                        onDelete: () => _confirmDelete(context, product),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, {Product? product}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
  }

  void _openDetail(BuildContext context, {required Product product}) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  void _openStockIn(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StockInScreen(productId: product.id)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"? This will be recorded in the audit log and can be restored by the admin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(productMutationControllerProvider.notifier).delete(product.id);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(productMutationControllerProvider).error ?? 'Delete failed')),
      );
    }
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    this.onTap,
    required this.onEdit,
    required this.onStockIn,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onStockIn;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lowStock = product.isLowStock;
    final typeIcon = _typeIcon(product.productType);
    final typeLabel = _typeLabel(product.productType);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(typeLabel, style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                        if (lowStock)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('LOW', style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        product.categoryName ?? 'Uncategorized',
                        if (product.brand.isNotEmpty) product.brand,
                        if (product.sku.isNotEmpty) product.sku,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _typeDetail(product),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Cost ${Formatters.currency(product.costPrice)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: lowStock ? AppColors.danger.withValues(alpha: 0.12) : AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _stockLabel(product),
                            style: TextStyle(
                              color: lowStock ? AppColors.danger : AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeDetail(Product p) {
    switch (p.productType) {
      case 'carpet':
        if (p.carpetPiecesData.isNotEmpty) {
          return '${p.carpetPiecesData.length} pieces | ${p.quantity} sqft';
        }
        if (p.carpetWidth > 0 && p.carpetHeight > 0) {
          return '${p.carpetWidth}m x ${p.carpetHeight}m | ${p.quantity} sqft';
        }
        return '${p.quantity} sqft';
      case 'meter':
        return '${p.meterLength}m | ${Formatters.currency(p.costPerMeter)}/m';
      case 'foam':
        if (p.sizeStocks.isNotEmpty) {
          final total = p.sizeStocks.fold(0, (sum, s) => sum + s.pieces);
          return '${p.sizeStocks.length} size${p.sizeStocks.length == 1 ? '' : 's'} | $total pcs';
        }
        final parts = <String>[];
        if (p.foamLength > 0 && p.foamWidth > 0) {
          parts.add('${_trim(p.foamLength)}ft x ${_trim(p.foamWidth)}ft');
        }
        if (p.foamThickness > 0) parts.add('${_trim(p.foamThickness)}in thick');
        parts.add('${p.quantity} pcs');
        return parts.join(' | ');
      case 'pillow':
        final sz = p.pillowSize.isNotEmpty ? p.pillowSize : p.size;
        return '${sz.isEmpty ? 'Pillow' : sz} | ${p.quantity} pcs';
      case 'qaleen':
        if (p.qaleenSizes.isNotEmpty) {
          final total = p.qaleenSizes.fold(0, (sum, s) => sum + s.pieces);
          return '${p.qaleenSizes.length} sizes | $total pieces';
        }
        return '${p.quantity} pieces | ${Formatters.currency(p.costPerPiece)}/pc';
      default:
        return '';
    }
  }

  String _stockLabel(Product p) {
    switch (p.productType) {
      case 'carpet':
        return '${p.quantity} sqft';
      case 'meter':
        return '${p.meterLength}m';
      case 'qaleen':
      case 'foam':
      case 'pillow':
        return '${p.quantity} pcs';
      default:
        return '${p.quantity} in stock';
    }
  }

  String _trim(double v) => v == v.truncateToDouble() ? '${v.toInt()}' : '$v';
}

IconData _typeIcon(String t) {
  switch (t) {
    case 'carpet':
      return Icons.grid_on;
    case 'meter':
      return Icons.straighten;
    case 'foam':
      return Icons.weekend_outlined;
    case 'pillow':
      return Icons.king_bed_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

String _typeLabel(String t) {
  switch (t) {
    case 'carpet':
      return 'Carpet';
    case 'meter':
      return 'Meter';
    case 'foam':
      return 'Foam';
    case 'pillow':
      return 'Pillow';
    default:
      return 'Qaleen';
  }
}
