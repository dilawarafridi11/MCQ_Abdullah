import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/status_views.dart';
import '../../products/models/product.dart';
import '../providers/product_providers.dart';

const _typeOptions = <({String value, String label, IconData icon})>[
  (value: 'qaleen', label: 'Qaleen', icon: Icons.inventory_2_outlined),
  (value: 'carpet', label: 'Carpet', icon: Icons.grid_on),
  (value: 'meter', label: 'Meter', icon: Icons.straighten),
  (value: 'foam', label: 'Foam', icon: Icons.weekend_outlined),
  (value: 'pillow', label: 'Pillows', icon: Icons.king_bed_outlined),
];

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _size;
  late final TextEditingController _costPerPiece;
  late final TextEditingController _costPerSqft;
  late final TextEditingController _carpetWidth;
  late final TextEditingController _carpetHeight;
  late final TextEditingController _carpetPieces;
  late final TextEditingController _meterLength;
  late final TextEditingController _costPerMeter;
  late final TextEditingController _foamLength;
  late final TextEditingController _foamWidth;
  late final TextEditingController _foamThickness;
  late final TextEditingController _quantity;
  late final TextEditingController _costPrice;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _pillowSize;

  late String _productType;
  List<ColorStock> _colorStocks = [];
  Uint8List? _productImageBytes;
  bool _imageRemoved = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _isEdit = p != null;
    final existingType = p?.productType ?? '';
    _productType = existingType.isEmpty ? 'qaleen' : existingType;

    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _size = TextEditingController(text: p?.size ?? '');
    _costPerPiece = TextEditingController(text: p != null && p.costPerPiece > 0 ? _fmt(p.costPerPiece) : '');
    _costPerSqft = TextEditingController(text: p != null && p.costPerSqft > 0 ? _fmt(p.costPerSqft) : '');
    _carpetWidth = TextEditingController(text: p != null && p.carpetWidth > 0 ? _fmt(p.carpetWidth) : '');
    _carpetHeight = TextEditingController(text: p != null && p.carpetHeight > 0 ? _fmt(p.carpetHeight) : '');
    _carpetPieces = TextEditingController(text: p != null && p.carpetPieces > 0 ? '${p.carpetPieces}' : '');
    _meterLength = TextEditingController(text: p != null && p.meterLength > 0 ? _fmt(p.meterLength) : '');
    _costPerMeter = TextEditingController(text: p != null && p.costPerMeter > 0 ? _fmt(p.costPerMeter) : '');
    _foamLength = TextEditingController(text: p != null && p.foamLength > 0 ? _fmt(p.foamLength) : '');
    _foamWidth = TextEditingController(text: p != null && p.foamWidth > 0 ? _fmt(p.foamWidth) : '');
    _foamThickness = TextEditingController(text: p != null && p.foamThickness > 0 ? _fmt(p.foamThickness) : '');
    _quantity = TextEditingController(text: p != null && p.quantity > 0 ? '${p.quantity}' : '');
    _costPrice = TextEditingController(text: p != null && p.costPrice > 0 ? _fmt(p.costPrice) : '');
    _sellingPrice = TextEditingController(text: p != null && p.sellingPrice > 0 ? _fmt(p.sellingPrice) : '');
    _pillowSize = TextEditingController(text: p?.pillowSize ?? '');

    _colorStocks = p?.colorStocks.toList() ?? [];
    final existingImage = (p?.images.isNotEmpty ?? false) ? p!.images.first : '';
    if (existingImage.startsWith('data:image')) {
      try {
        _productImageBytes = base64.decode(existingImage.split(',').last);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _size.dispose();
    _costPerPiece.dispose();
    _costPerSqft.dispose();
    _carpetWidth.dispose();
    _carpetHeight.dispose();
    _carpetPieces.dispose();
    _meterLength.dispose();
    _costPerMeter.dispose();
    _foamLength.dispose();
    _foamWidth.dispose();
    _foamThickness.dispose();
    _quantity.dispose();
    _costPrice.dispose();
    _sellingPrice.dispose();
    _pillowSize.dispose();
    super.dispose();
  }

  static String _fmt(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  double _toDouble(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  int get _colorStockQty => _colorStocks.fold(0, (sum, c) => sum + c.pieces);

  int get _computedQuantity {
    switch (_productType) {
      case 'qaleen':
        return _colorStockQty;
      case 'carpet':
        return (_toDouble(_carpetWidth) * _toDouble(_carpetHeight)).round();
      case 'meter':
        return _toDouble(_meterLength).round();
      default:
        return int.tryParse(_quantity.text.trim()) ?? 0;
    }
  }

  String get _stockUnit {
    switch (_productType) {
      case 'carpet':
        return 'sqft';
      case 'meter':
        return 'm';
      default:
        return 'pcs';
    }
  }

  String _buildImageDataUrl(Uint8List bytes) {
    final ext = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 ? 'png' : 'jpeg';
    return 'data:image/$ext;base64,${base64.encode(bytes)}';
  }

  Future<void> _pickProductImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _productImageBytes = bytes;
      _imageRemoved = false;
    });
  }

  void _addColorStock() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final colorCtrl = TextEditingController();
        final setsCtrl = TextEditingController();
        final piecesCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Colour', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: colorCtrl,
                decoration: const InputDecoration(labelText: 'Colour', prefixIcon: Icon(Icons.color_lens_outlined)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: setsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sets'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: piecesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pieces'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  final color = colorCtrl.text.trim();
                  if (color.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please enter a colour')),
                    );
                    return;
                  }
                  setState(() {
                    _colorStocks = [
                      ..._colorStocks,
                      ColorStock(
                        color: color,
                        sets: int.tryParse(setsCtrl.text.trim()) ?? 0,
                        pieces: int.tryParse(piecesCtrl.text.trim()) ?? 0,
                      ),
                    ];
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Add Colour'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(productMutationControllerProvider.notifier);
    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'sku': _sku.text.trim(),
      'size': _size.text.trim(),
      'productType': _productType,
      'sellingPrice': _toDouble(_sellingPrice),
    };

    switch (_productType) {
      case 'carpet':
        data['carpetWidth'] = _toDouble(_carpetWidth);
        data['carpetHeight'] = _toDouble(_carpetHeight);
        data['carpetPieces'] = int.tryParse(_carpetPieces.text.trim()) ?? 0;
        data['costPerSqft'] = _toDouble(_costPerSqft);
        break;
      case 'qaleen':
        data['colorStocks'] = _colorStocks.map((c) => c.toJson()).toList();
        data['costPerPiece'] = _toDouble(_costPerPiece);
        break;
      case 'meter':
        data['meterLength'] = _toDouble(_meterLength);
        data['costPerMeter'] = _toDouble(_costPerMeter);
        break;
      case 'foam':
        data['foamLength'] = _toDouble(_foamLength);
        data['foamWidth'] = _toDouble(_foamWidth);
        data['foamThickness'] = _toDouble(_foamThickness);
        data['quantity'] = int.tryParse(_quantity.text.trim()) ?? 0;
        data['costPrice'] = _toDouble(_costPrice);
        break;
      case 'pillow':
        data['pillowSize'] = _pillowSize.text.trim();
        data['quantity'] = int.tryParse(_quantity.text.trim()) ?? 0;
        data['costPrice'] = _toDouble(_costPrice);
        break;
    }

    if (_productImageBytes != null) {
      data['images'] = [_buildImageDataUrl(_productImageBytes!)];
    } else if (_imageRemoved) {
      data['images'] = <String>[];
    } else if (_isEdit && widget.product!.images.isNotEmpty) {
      data['images'] = widget.product!.images;
    }

    final ok = _isEdit
        ? await notifier.update(widget.product!.id, data)
        : await notifier.create(data);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(productMutationControllerProvider).error ?? 'Failed to save product')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(productMutationControllerProvider.select((s) => s.loading));

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Product' : 'Add Product')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                validator: (v) => Validators.required(v),
                decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(Icons.carpenter_outlined)),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _productType,
                decoration: const InputDecoration(
                  labelText: 'Product Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _typeOptions
                    .map((o) => DropdownMenuItem(
                          value: o.value,
                          child: Row(
                            children: [
                              Icon(o.icon, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Text(o.label),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _productType = v);
                },
              ),
              const SizedBox(height: 14),

              _buildProductImagePicker(),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sku,
                      decoration: const InputDecoration(labelText: 'Product Code / SKU', prefixIcon: Icon(Icons.tag)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _size,
                      decoration: const InputDecoration(labelText: 'Size (e.g. 200 × 300)', prefixIcon: Icon(Icons.straighten)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildTypeFields(),
              const SizedBox(height: 24),

              LoadingButton(
                loading: loading,
                label: _isEdit ? 'Update Product' : 'Add Product',
                icon: _isEdit ? Icons.save_outlined : Icons.add,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------ dynamic type fields --

  Widget _buildTypeFields() {
    switch (_productType) {
      case 'carpet':
        return _SectionCard(
          title: 'Carpet Details',
          subtitle: 'Stock is computed as width × height',
          children: [
            _NumField(controller: _carpetWidth, label: 'Width (m)', icon: Icons.straighten),
            const SizedBox(height: 12),
            _NumField(controller: _carpetHeight, label: 'Height (m)', icon: Icons.height),
            const SizedBox(height: 12),
            _NumField(controller: _carpetPieces, label: 'Rolls / Pieces', icon: Icons.layers_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _NumField(controller: _costPerSqft, label: 'Cost / sqft', icon: Icons.attach_money, prefix: 'Rs. ')),
                const SizedBox(width: 10),
                Expanded(child: _NumField(controller: _sellingPrice, label: 'Selling Price', icon: Icons.sell_outlined, prefix: 'Rs. ')),
              ],
            ),
          ],
        );
      case 'qaleen':
        return Column(
          children: [
            _buildColorStocksSection(),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Pricing',
              subtitle: 'Per piece',
              children: [
                Row(
                  children: [
                    Expanded(child: _NumField(controller: _costPerPiece, label: 'Cost / piece', icon: Icons.attach_money, prefix: 'Rs. ')),
                    const SizedBox(width: 10),
                    Expanded(child: _NumField(controller: _sellingPrice, label: 'Selling Price', icon: Icons.sell_outlined, prefix: 'Rs. ')),
                  ],
                ),
              ],
            ),
          ],
        );
      case 'meter':
        return _SectionCard(
          title: 'Meter Details',
          subtitle: 'Stock is the meter length',
          children: [
            _NumField(controller: _meterLength, label: 'Meter Length (m)', icon: Icons.straighten),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _NumField(controller: _costPerMeter, label: 'Cost / meter', icon: Icons.attach_money, prefix: 'Rs. ')),
                const SizedBox(width: 10),
                Expanded(child: _NumField(controller: _sellingPrice, label: 'Selling Price', icon: Icons.sell_outlined, prefix: 'Rs. ')),
              ],
            ),
          ],
        );
      case 'foam':
        return _SectionCard(
          title: 'Foam Details',
          subtitle: 'Track pieces & dimensions',
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                SizedBox(width: 100, child: _NumField(controller: _foamLength, label: 'Length (ft)', icon: Icons.straighten)),
                SizedBox(width: 100, child: _NumField(controller: _foamWidth, label: 'Width (ft)', icon: Icons.height)),
                SizedBox(width: 100, child: _NumField(controller: _foamThickness, label: 'Thickness (in)', icon: Icons.vertical_align_center)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _NumField(controller: _quantity, label: 'Pieces', icon: Icons.inventory_2_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _NumField(controller: _costPrice, label: 'Cost / piece', icon: Icons.attach_money, prefix: 'Rs. ')),
              ],
            ),
            const SizedBox(height: 12),
            _NumField(controller: _sellingPrice, label: 'Selling Price', icon: Icons.sell_outlined, prefix: 'Rs. '),
          ],
        );
      case 'pillow':
        return _SectionCard(
          title: 'Pillow Details',
          subtitle: 'Track pieces & pricing',
          children: [
            TextFormField(
              controller: _pillowSize,
              decoration: const InputDecoration(labelText: 'Pillow Size (e.g. 18 × 18)', prefixIcon: Icon(Icons.square_foot)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _NumField(controller: _quantity, label: 'Pieces', icon: Icons.inventory_2_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _NumField(controller: _costPrice, label: 'Cost / piece', icon: Icons.attach_money, prefix: 'Rs. ')),
              ],
            ),
            const SizedBox(height: 12),
            _NumField(controller: _sellingPrice, label: 'Selling Price', icon: Icons.sell_outlined, prefix: 'Rs. '),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProductImagePicker() {
    return Row(
      children: [
        GestureDetector(
          onTap: _pickProductImage,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _productImageBytes != null
                ? Image.memory(_productImageBytes!, fit: BoxFit.cover, width: 84, height: 84)
                : const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 30),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Product Image', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Shown on the dashboard product card',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              if (_productImageBytes != null)
                TextButton(
                  onPressed: () => setState(() {
                    _productImageBytes = null;
                    _imageRemoved = true;
                  }),
                  child: const Text('Remove image'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorStocksSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Colours & Stock (Sets / Pieces)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _addColorStock,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_colorStocks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Add colours to track sets and pieces per colour. Total stock: $_computedQuantity $_stockUnit.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            )
          else
            ...List.generate(_colorStocks.length, (i) {
              final c = _colorStocks[i];
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c.color, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Text('Sets: ${c.sets}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 10),
                    Text('Pieces: ${c.pieces}', style: const TextStyle(fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _colorStocks.removeAt(i)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.prefix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: prefix,
        border: const OutlineInputBorder(),
      ),
    );
  }
}