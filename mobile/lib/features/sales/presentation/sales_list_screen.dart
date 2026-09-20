import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bar_brand.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/sale.dart';
import '../providers/sale_providers.dart';
import '../services/invoice_pdf.dart';

class SalesListScreen extends ConsumerWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleListControllerProvider);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppBarBrand(showText: false),
            const SizedBox(width: 10),
            Text('Sales'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(saleListControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Filter by date',
            onPressed: () => _pickDateRange(context, ref),
            icon: Icon(
              state.from != null || state.to != null ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: state.from != null || state.to != null ? AppColors.gold : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.from != null || state.to != null)
            _DateFilterBar(
              from: state.from,
              to: state.to,
              onClear: () =>
                  ref.read(saleListControllerProvider.notifier).setDateRange(null, null),
            ),
          Expanded(
            child: state.data.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.read(saleListControllerProvider.notifier).refresh(),
              ),
              data: (page) {
                if (page.sales.isEmpty) {
                  return const EmptyState(
                    icon: Icons.point_of_sale_outlined,
                    title: 'No sales found',
                    subtitle: 'No sales match this filter yet.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(saleListControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: page.sales.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _SaleTile(
                      sale: page.sales[index],
                      onTap: () => _openDetail(context, ref, page.sales[index]),
                      canDelete: !isAdmin,
                      onDelete: () => _confirmDelete(context, ref, page.sales[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(saleListControllerProvider);
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Filter sales by date',
      saveText: 'Apply',
      initialDateRange: current.from != null && current.to != null
          ? DateTimeRange(start: current.from!, end: current.to!)
          : null,
    );
    if (range == null) return;
    await ref.read(saleListControllerProvider.notifier).setDateRange(
          DateTime(range.start.year, range.start.month, range.start.day),
          DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
        );
  }

  void _openDetail(BuildContext context, WidgetRef ref, Sale sale) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Sale sale) async {
    final restock = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale'),
        content: Text('Delete sale ${sale.invoiceNo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Delete'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete & Restock'),
          ),
        ],
      ),
    );
    if (restock == null) return;
    final ok = await ref.read(saleMutationControllerProvider.notifier).delete(sale.id, restock: restock);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(saleMutationControllerProvider).error ?? 'Delete failed')),
      );
    }
  }
}

class _DateFilterBar extends StatelessWidget {
  const _DateFilterBar({required this.from, required this.to, required this.onClear});

  final DateTime? from;
  final DateTime? to;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = [
      if (from != null) 'From ${Formatters.date(from!)}',
      if (to != null) 'To ${Formatters.date(to!)}',
    ].join('  ·  ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range, size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, size: 14, color: AppColors.gold),
                  SizedBox(width: 2),
                  Text(
                    'Clear',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold),
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

class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({super.key, required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(sale.invoiceNo),
        actions: [
          IconButton(
            tooltip: 'Share invoice',
            onPressed: () => _shareInvoice(context, sale),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sale.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                        ),
                      ),
                      Text(
                        Formatters.currency(sale.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (sale.shopName.isNotEmpty) sale.shopName,
                      if (sale.createdByName.isNotEmpty) 'by ${sale.createdByName}',
                      Formatters.dateTime(sale.createdAt),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.payments_outlined,
                        label: AppConstants.paymentMethodLabels[sale.paymentMethod] ?? Formatters.title(sale.paymentMethod),
                      ),
                      if (sale.customerPhone.isNotEmpty)
                        _InfoChip(icon: Icons.phone_outlined, label: sale.customerPhone),
                      if (sale.profit > 0)
                        _InfoChip(icon: Icons.trending_up, label: 'Profit ${Formatters.currency(sale.profit)}', color: AppColors.success),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ...sale.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (item.isFoam) ...[
                                  if (item.foamQty > 0)
                                    _QtyLine(label: 'Foam', qty: item.foamQty, price: item.unitPrice),
                                  if (item.pillowQty > 0)
                                    _QtyLine(label: 'Pillows', qty: item.pillowQty, price: item.unitPrice),
                                  if (item.coverQty > 0)
                                    _QtyLine(label: 'Foam Covers', qty: item.coverQty, price: item.unitPrice),
                                ] else
                                  Text(
                                    '${item.quantity} x ${Formatters.currency(item.unitPrice)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.currency(item.totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    )),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DetailRow(label: 'Subtotal', value: Formatters.currency(sale.subtotal)),
                      _DetailRow(label: 'Discount', value: '- ${Formatters.currency(sale.discount)}'),
                      _DetailRow(
                        label: 'Total',
                        value: Formatters.currency(sale.totalAmount),
                        bold: true,
                        valueColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (sale.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.sticky_note_2_outlined),
                  title: Text('Notes', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(sale.notes),
                ),
              ),
            ),
        ],
      ),
    );
  }
Future<void> _shareInvoice(BuildContext context, Sale sale) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await InvoicePdf.build(sale);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Invoice_${sale.invoiceNo}.pdf');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          text: 'Invoice ${sale.invoiceNo} — Hayat Foam',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not share invoice: $e')));
    }
  }
}

class _QtyLine extends StatelessWidget {
  const _QtyLine({required this.label, required this.qty, required this.price});

  final String label;
  final int qty;
  final double price;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        '$label: $qty x ${Formatters.currency(price)}',
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? AppColors.secondary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color ?? AppColors.secondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 15 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.sale,
    required this.onTap,
    required this.canDelete,
    required this.onDelete,
  });

  final Sale sale;
  final VoidCallback onTap;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.point_of_sale_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sale.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        Text(
                          Formatters.currency(sale.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        sale.invoiceNo,
                        '${sale.totalItems} items',
                        AppConstants.paymentMethodLabels[sale.paymentMethod] ?? sale.paymentMethod,
                        if (sale.shopName.isNotEmpty) sale.shopName,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.dateTime(sale.createdAt),
                      style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
