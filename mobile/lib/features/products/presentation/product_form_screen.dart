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

  List<ColorStock> _colorStocks = [];
  Uint8List? _productImageBytes;
  bool _imageRemoved = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _isEdit = p != null;
    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _size = TextEditingController(text: p?.size ?? '');

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
    super.dispose();
  }

  int get _computedQuantity {
    return _colorStocks.fold(0, (sum, c) => sum + c.pieces);
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
      'colorStocks': _colorStocks.map((c) => c.toJson()).toList(),
    };

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

              _buildColorStocksSection(),
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
                'Add colours to track sets and pieces per colour. Total stock: $_computedQuantity.',
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