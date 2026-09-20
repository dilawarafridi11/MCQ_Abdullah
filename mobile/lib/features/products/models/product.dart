class QaleenSize {
  final double height;
  final double width;
  final int pieces;

  const QaleenSize({required this.height, required this.width, required this.pieces});

  factory QaleenSize.fromJson(Map<String, dynamic> json) => QaleenSize(
        height: (json['height'] as num?)?.toDouble() ?? 0,
        width: (json['width'] as num?)?.toDouble() ?? 0,
        pieces: (json['pieces'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'height': height, 'width': width, 'pieces': pieces};
}

class ColorStock {
  final String color;
  final int sets;
  final int pieces;
  final int quantity;

  const ColorStock({
    required this.color,
    this.sets = 0,
    this.pieces = 0,
    this.quantity = 0,
  });

  factory ColorStock.fromJson(Map<String, dynamic> json) => ColorStock(
        color: json['color']?.toString() ?? '',
        sets: (json['sets'] as num?)?.toInt() ?? 0,
        pieces: (json['pieces'] as num?)?.toInt() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      );

  int get onHand => quantity > 0 ? quantity : pieces;

  Map<String, dynamic> toJson() =>
      {'color': color, 'sets': sets, 'pieces': pieces, if (quantity > 0) 'quantity': quantity};
}

class SizeStock {
  final String size;
  final int pieces;

  const SizeStock({required this.size, this.pieces = 0});

  factory SizeStock.fromJson(Map<String, dynamic> json) => SizeStock(
        size: json['size']?.toString() ?? '',
        pieces: (json['pieces'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'size': size, 'pieces': pieces};
}

class CarpetPieceData {
  final double width;
  final double height;
  final double area;
  final String color;
  final String image;

  const CarpetPieceData({
    required this.width,
    required this.height,
    this.area = 0,
    this.color = '',
    this.image = '',
  });

  factory CarpetPieceData.fromJson(Map<String, dynamic> json) => CarpetPieceData(
        width: (json['width'] as num?)?.toDouble() ?? 0,
        height: (json['height'] as num?)?.toDouble() ?? 0,
        area: (json['area'] as num?)?.toDouble() ?? 0,
        color: json['color']?.toString() ?? '',
        image: json['image']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'area': area,
        'color': color,
        if (image.isNotEmpty) 'image': image,
      };
}

class Product {
  final String id;
  final String name;
  final String sku;
  final String barcode;
  final String? categoryId;
  final String? categoryName;
  final String brand;
  final String supplier;
  final String productType;
  final double carpetWidth;
  final double carpetHeight;
  final int carpetPieces;
  final List<CarpetPieceData> carpetPiecesData;
  final double costPerSqft;
  final double costPerPiece;
  final List<QaleenSize> qaleenSizes;
  final double meterLength;
  final double costPerMeter;
  final double foamLength;
  final double foamWidth;
  final double foamThickness;
  final String pillowSize;
  final List<SizeStock> sizeStocks;
  final int pillowStock;
  final int coverStock;
  final double costPrice;
  final double sellingPrice;
  final int quantity;
  final int lowStockThreshold;
  final String color;
  final String size;
  final String description;
  final List<String> images;
  final List<ColorStock> colorStocks;
  final String? shopId;
  final String? shopName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.barcode = '',
    this.categoryId,
    this.categoryName,
    this.brand = '',
    this.supplier = '',
    this.productType = 'qaleen',
    this.carpetWidth = 0,
    this.carpetHeight = 0,
    this.carpetPieces = 0,
    this.carpetPiecesData = const [],
    this.costPerSqft = 0,
    this.costPerPiece = 0,
    this.qaleenSizes = const [],
    this.meterLength = 0,
    this.costPerMeter = 0,
    this.foamLength = 0,
    this.foamWidth = 0,
    this.foamThickness = 0,
    this.pillowSize = '',
    this.sizeStocks = const [],
    this.pillowStock = 0,
    this.coverStock = 0,
    required this.costPrice,
    this.sellingPrice = 0,
    this.quantity = 0,
    this.lowStockThreshold = 5,
    this.color = '',
    this.size = '',
    this.description = '',
    this.images = const [],
    this.colorStocks = const [],
    this.shopId,
    this.shopName,
    this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => quantity <= lowStockThreshold;

  double get stockValue => quantity * costPrice;

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    String? catId;
    String? catName;
    if (category is Map<String, dynamic>) {
      catId = (category['id'] ?? category['_id'])?.toString();
      catName = category['name']?.toString();
    } else if (category != null) {
      catId = category.toString();
    }
    final shop = json['shop'];
    String? sId;
    String? sName;
    if (shop is Map<String, dynamic>) {
      sId = (shop['id'] ?? shop['_id'])?.toString();
      sName = shop['name']?.toString();
    } else if (shop != null) {
      sId = shop.toString();
    }

    return Product(
      id: (json['id'] ?? json['_id']).toString(),
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      categoryId: catId,
      categoryName: catName,
      brand: json['brand']?.toString() ?? '',
      supplier: json['supplier']?.toString() ?? '',
      productType: json['productType']?.toString() ?? 'qaleen',
      carpetWidth: (json['carpetWidth'] as num?)?.toDouble() ?? 0,
      carpetHeight: (json['carpetHeight'] as num?)?.toDouble() ?? 0,
      carpetPieces: (json['carpetPieces'] as num?)?.toInt() ?? 0,
      carpetPiecesData: (json['carpetPiecesData'] as List?)
              ?.map((e) => CarpetPieceData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      costPerSqft: (json['costPerSqft'] as num?)?.toDouble() ?? 0,
      costPerPiece: (json['costPerPiece'] as num?)?.toDouble() ?? 0,
      qaleenSizes: (json['qaleenSizes'] as List?)
              ?.map((e) => QaleenSize.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      meterLength: (json['meterLength'] as num?)?.toDouble() ?? 0,
      costPerMeter: (json['costPerMeter'] as num?)?.toDouble() ?? 0,
      foamLength: (json['foamLength'] as num?)?.toDouble() ?? 0,
      foamWidth: (json['foamWidth'] as num?)?.toDouble() ?? 0,
      foamThickness: (json['foamThickness'] as num?)?.toDouble() ?? 0,
      pillowSize: json['pillowSize']?.toString() ?? '',
      sizeStocks: (json['sizeStocks'] as List?)
              ?.map((e) => SizeStock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      pillowStock: (json['pillowStock'] as num?)?.toInt() ?? 0,
      coverStock: (json['coverStock'] as num?)?.toInt() ?? 0,
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 5,
      color: json['color']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      colorStocks: (json['colorStocks'] as List?)
              ?.map((e) => ColorStock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      shopId: sId,
      shopName: sName,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'category': categoryId,
        'brand': brand,
        'supplier': supplier,
        'productType': productType,
        'carpetWidth': carpetWidth,
        'carpetHeight': carpetHeight,
        'carpetPieces': carpetPieces,
        'carpetPiecesData': carpetPiecesData.map((p) => p.toJson()).toList(),
        'costPerSqft': costPerSqft,
        'costPerPiece': costPerPiece,
        'qaleenSizes': qaleenSizes.map((s) => s.toJson()).toList(),
        'meterLength': meterLength,
        'costPerMeter': costPerMeter,
        'foamLength': foamLength,
        'foamWidth': foamWidth,
        'foamThickness': foamThickness,
        'pillowSize': pillowSize,
        'sizeStocks': sizeStocks.map((s) => s.toJson()).toList(),
        'pillowStock': pillowStock,
        'coverStock': coverStock,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'lowStockThreshold': lowStockThreshold,
        'color': color,
        'size': size,
        'description': description,
        'images': images,
        'colorStocks': colorStocks.map((c) => c.toJson()).toList(),
      };
}
