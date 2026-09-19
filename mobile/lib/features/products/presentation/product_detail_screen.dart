import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/product.dart';
import '../providers/product_providers.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late Product _product;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: _product)),
    );
    if (mounted) ref.read(productListControllerProvider.notifier).refresh();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 32),
        title: const Text('Delete Product'),
        content: Text('Remove "${_product.name}"? This will be recorded in the audit log and can be restored by the admin.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(productMutationControllerProvider.notifier).delete(_product.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(productMutationControllerProvider).error ?? 'Delete failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final p = _product;
    final typeIcon = switch (p.productType) {
      'carpet' => Icons.grid_on,
      'meter' => Icons.straighten,
      'foam' => Icons.weekend_outlined,
      'pillow' => Icons.king_bed_outlined,
      _ => Icons.inventory_2_outlined,
    };
    final typeLabel = switch (p.productType) {
      'carpet' => 'Carpet',
      'meter' => 'Meter',
      'foam' => 'Foam',
      'pillow' => 'Pillow',
      _ => 'Qaleen',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(productListControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(typeIcon, color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [p.categoryName ?? 'Uncategorized', if (p.brand.isNotEmpty) p.brand]
                                  .join(' · '),
                              style: TextStyle(fontSize: 13, color: secondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          typeLabel,
                          style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.payments_outlined,
                          label: 'Cost Price',
                          value: Formatters.currency(p.costPrice),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.sell_outlined,
                          label: 'Selling Price',
                          value: Formatters.currency(p.sellingPrice),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: p.isLowStock ? Icons.warning_amber : Icons.inventory_2_outlined,
                          label: 'Stock',
                          value: _stockLabel(p),
                          valueColor: p.isLowStock ? AppColors.danger : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.storefront_outlined,
                          label: 'Supplier',
                          value: p.supplier.isEmpty ? '—' : p.supplier,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Product Information',
              icon: Icons.info_outline,
              children: [
                _InfoRow(icon: Icons.qr_code_2, label: 'Barcode', value: p.barcode.isEmpty ? '—' : p.barcode),
                if (p.sku.isNotEmpty) _InfoRow(icon: Icons.tag, label: 'SKU', value: p.sku),
                if (p.color.isNotEmpty) _InfoRow(icon: Icons.palette_outlined, label: 'Color', value: p.color),
                if (p.size.isNotEmpty) _InfoRow(icon: Icons.straighten, label: 'Size', value: p.size),
                if (p.description.isNotEmpty)
                  _InfoRow(icon: Icons.notes_outlined, label: 'Description', value: p.description),
                if (p.shopName != null && p.shopName!.isNotEmpty)
                  _InfoRow(icon: Icons.store_outlined, label: 'Shop', value: p.shopName!),
                _InfoRow(icon: Icons.calendar_today_outlined, label: 'Added On', value: Formatters.date(p.createdAt)),
              ],
            ),
            const SizedBox(height: 16),
            _buildPiecesSection(context, p),
          ],
        ),
      ),
    );
  }

  Widget _buildPiecesSection(BuildContext context, Product p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pieces = p.carpetPiecesData;
    switch (p.productType) {
      case 'carpet':
        if (pieces.isEmpty) {
          return _SectionCard(
            title: 'Pieces',
            icon: Icons.layers_outlined,
            children: [
              _InfoRow(
                icon: Icons.straighten,
                label: 'Dimensions',
                value: p.carpetWidth > 0 && p.carpetHeight > 0
                    ? '${p.carpetWidth}m x ${p.carpetHeight}m'
                    : '—',
              ),
              _InfoRow(icon: Icons.inventory_2_outlined, label: 'Rolls', value: '${p.carpetPieces} rolls'),
              if (p.costPerSqft > 0)
                _InfoRow(icon: Icons.attach_money, label: 'Cost / sqft', value: Formatters.currency(p.costPerSqft)),
            ],
          );
        }
        return _SectionCard(
          title: 'Pieces (${pieces.length})',
          icon: Icons.layers_outlined,
          children: [
            for (var i = 0; i < pieces.length; i++) ...[
              _PieceCard(index: i, piece: pieces[i], showDivider: i < pieces.length - 1),
            ],
          ],
        );
      case 'qaleen':
        if (p.qaleenSizes.isEmpty) {
          return _SectionCard(
            title: 'Pieces',
            icon: Icons.layers_outlined,
            children: [
              _InfoRow(
                icon: Icons.inventory_2_outlined,
                label: 'Quantity',
                value: '${p.quantity} pieces',
              ),
              if (p.costPerPiece > 0)
                _InfoRow(icon: Icons.attach_money, label: 'Cost / piece', value: Formatters.currency(p.costPerPiece)),
            ],
          );
        }
        return _SectionCard(
          title: 'Pieces (${p.qaleenSizes.length} sizes)',
          icon: Icons.layers_outlined,
          children: [
            for (var i = 0; i < p.qaleenSizes.length; i++) ...[
              _SizeRow(
                index: i,
                size: p.qaleenSizes[i],
                dark: isDark,
                showDivider: i < p.qaleenSizes.length - 1,
              ),
            ],
          ],
        );
      case 'meter':
        return _SectionCard(
          title: 'Pieces',
          icon: Icons.layers_outlined,
          children: [
            _InfoRow(icon: Icons.straighten, label: 'Length', value: '${p.meterLength}m'),
            _InfoRow(icon: Icons.inventory_2_outlined, label: 'Quantity', value: '${p.quantity} pieces'),
            if (p.costPerMeter > 0)
              _InfoRow(icon: Icons.attach_money, label: 'Cost / meter', value: Formatters.currency(p.costPerMeter)),
          ],
        );
      case 'foam':
        return _SectionCard(
          title: 'Pieces',
          icon: Icons.layers_outlined,
          children: [
            _InfoRow(
              icon: Icons.square_foot,
              label: 'Dimensions',
              value: p.foamLength > 0 || p.foamWidth > 0
                  ? '${_dim(p.foamLength)}ft x ${_dim(p.foamWidth)}ft'
                  : '—',
            ),
            if (p.foamThickness > 0)
              _InfoRow(icon: Icons.vertical_align_center, label: 'Thickness', value: '${_dim(p.foamThickness)}in'),
            _InfoRow(icon: Icons.inventory_2_outlined, label: 'Quantity', value: '${p.quantity} pieces'),
            if (p.costPrice > 0)
              _InfoRow(icon: Icons.attach_money, label: 'Cost / piece', value: Formatters.currency(p.costPrice)),
          ],
        );
      case 'pillow':
        return _SectionCard(
          title: 'Pieces',
          icon: Icons.layers_outlined,
          children: [
            _InfoRow(
              icon: Icons.square_foot,
              label: 'Size',
              value: p.pillowSize.isNotEmpty ? p.pillowSize : (p.size.isEmpty ? '—' : p.size),
            ),
            _InfoRow(icon: Icons.inventory_2_outlined, label: 'Quantity', value: '${p.quantity} pieces'),
            if (p.costPrice > 0)
              _InfoRow(icon: Icons.attach_money, label: 'Cost / piece', value: Formatters.currency(p.costPrice)),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _dim(double v) => v == v.truncateToDouble() ? '${v.toInt()}' : '$v';

  String _stockLabel(Product p) {
    switch (p.productType) {
      case 'carpet':
        return '${p.quantity} sqft';
      case 'meter':
        return '${p.meterLength}m';
      default:
        return '${p.quantity} pcs';
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.darkTextSecondary : Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121218) : const Color(0xFFF7F5F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.goldDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: secondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF17151C)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.goldDark),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.goldDark),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _PieceCard extends StatelessWidget {
  const _PieceCard({required this.index, required this.piece, required this.showDivider});

  final int index;
  final CarpetPieceData piece;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PieceImage(image: piece.image),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Piece ${index + 1}',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    _ChipDetail(
                      icon: Icons.straighten,
                      text: '${_trim(piece.width)}m x ${_trim(piece.height)}m',
                    ),
                    if (piece.area > 0)
                      _ChipDetail(
                        icon: Icons.square_foot,
                        text: '${Formatters.number(piece.area)} sqft',
                      ),
                    if (piece.color.isNotEmpty) _ChipDetail(icon: Icons.palette_outlined, text: piece.color),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
      ],
    );
  }

  String _trim(double v) => v == v.truncateToDouble() ? '${v.toInt()}' : '$v';
}

class _SizeRow extends StatelessWidget {
  const _SizeRow({
    required this.index,
    required this.size,
    required this.showDivider,
    required this.dark,
  });

  final int index;
  final QaleenSize size;
  final bool showDivider;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.straighten, size: 18, color: AppColors.goldDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${size.width}m x ${size.height}m',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Size ${index + 1}',
                      style: TextStyle(fontSize: 11.5, color: dark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${size.pieces} pcs',
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: dark ? Colors.white10 : Colors.black12),
      ],
    );
  }
}

class _ChipDetail extends StatelessWidget {
  const _ChipDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.goldDark),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _PieceImage extends StatelessWidget {
  const _PieceImage({required this.image});

  final String image;

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
    if (image.isEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.image_not_supported_outlined, color: AppColors.primary),
      );
    }
    ImageProvider provider;
    if (image.startsWith('data:image')) {
      try {
        final bytes = base64.decode(image.split(',').last);
        provider = MemoryImage(bytes);
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
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 64,
          height: 64,
          color: AppColors.primary.withValues(alpha: 0.08),
          child: const Icon(Icons.image_not_supported_outlined, color: AppColors.primary),
        ),
      ),
    );
  }
}