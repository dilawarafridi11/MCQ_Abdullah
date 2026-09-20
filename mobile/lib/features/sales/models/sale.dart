class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final int foamQty;
  final int pillowQty;
  final int coverQty;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    this.foamQty = 0,
    this.pillowQty = 0,
    this.coverQty = 0,
  });

  bool get isFoam => foamQty > 0 || pillowQty > 0 || coverQty > 0;

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    return SaleItem(
      productId: product is Map<String, dynamic>
          ? (product['id'] ?? product['_id']).toString()
          : product?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      foamQty: (json['foamQty'] as num?)?.toInt() ?? 0,
      pillowQty: (json['pillowQty'] as num?)?.toInt() ?? 0,
      coverQty: (json['coverQty'] as num?)?.toInt() ?? 0,
    );
  }
}

class WhatsAppReceipt {
  final bool attempted;
  final bool sent;
  final String reason;
  final String? error;

  const WhatsAppReceipt({
    required this.attempted,
    required this.sent,
    this.reason = '',
    this.error,
  });

  factory WhatsAppReceipt.fromJson(Map<String, dynamic> json) => WhatsAppReceipt(
        attempted: json['attempted'] == true,
        sent: json['sent'] == true,
        reason: json['reason']?.toString() ?? '',
        error: json['error']?.toString(),
      );
}

class Sale {
  final String id;
  final String invoiceNo;
  final String shopId;
  final String shopName;
  final String customerName;
  final String customerPhone;
  final List<SaleItem> items;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final double paidAmount;
  final double dueAmount;
  final double profit;
  final String paymentMethod;
  final String notes;
  final String createdById;
  final String createdByName;
  final DateTime? createdAt;
  final WhatsAppReceipt? whatsappReceipt;

  const Sale({
    required this.id,
    required this.invoiceNo,
    required this.shopId,
    this.shopName = '',
    this.customerName = 'Walk-in Customer',
    this.customerPhone = '',
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.dueAmount = 0,
    this.profit = 0,
    this.paymentMethod = 'cash',
    this.notes = '',
    this.createdById = '',
    this.createdByName = '',
    this.createdAt,
    this.whatsappReceipt,
  });

  int get totalItems => items.fold(0, (a, i) => a + i.quantity);

  factory Sale.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'];
    String sId = (json['shopId'] ?? json['shop'])?.toString() ?? '';
    String sName = '';
    if (shop is Map<String, dynamic>) {
      sId = (shop['id'] ?? shop['_id']).toString();
      sName = shop['name']?.toString() ?? '';
    }
    final createdBy = json['createdBy'];
    String cbId = '';
    String cbName = '';
    if (createdBy is Map<String, dynamic>) {
      cbId = (createdBy['id'] ?? createdBy['_id']).toString();
      cbName = createdBy['name']?.toString() ?? '';
    } else if (createdBy != null) {
      cbId = createdBy.toString();
    }

    return Sale(
      id: (json['id'] ?? json['_id']).toString(),
      invoiceNo: json['invoiceNo']?.toString() ?? '',
      shopId: sId,
      shopName: sName,
      customerName: json['customerName']?.toString() ?? 'Walk-in Customer',
      customerPhone: json['customerPhone']?.toString() ?? '',
      items: (json['items'] as List?)
              ?.map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      dueAmount: (json['dueAmount'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      notes: json['notes']?.toString() ?? '',
      createdById: cbId,
      createdByName: cbName,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      whatsappReceipt: json['whatsappReceipt'] is Map<String, dynamic>
          ? WhatsAppReceipt.fromJson(json['whatsappReceipt'] as Map<String, dynamic>)
          : null,
    );
  }
}
