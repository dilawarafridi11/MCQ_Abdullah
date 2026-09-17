class ChartPoint {
  final String label;
  final double sales;
  final double profit;
  final double expenses;
  final String? date;

  const ChartPoint({
    required this.label,
    this.sales = 0,
    this.profit = 0,
    this.expenses = 0,
    this.date,
  });

  factory ChartPoint.fromJson(Map<String, dynamic> json) => ChartPoint(
        label: json['label']?.toString() ?? '',
        date: json['date']?.toString(),
        sales: (json['sales'] as num?)?.toDouble() ?? 0,
        profit: (json['profit'] as num?)?.toDouble() ?? 0,
        expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
      );
}

class ShopComparison {
  final String shopId;
  final String? shopName;
  final String? manager;
  final double sales;
  final double expenses;
  final double profit;
  final int saleCount;

  const ShopComparison({
    required this.shopId,
    this.shopName,
    this.manager,
    this.sales = 0,
    this.expenses = 0,
    this.profit = 0,
    this.saleCount = 0,
  });

  factory ShopComparison.fromJson(Map<String, dynamic> json) => ShopComparison(
        shopId: (json['shopId'] ?? json['shop'] ?? '').toString(),
        shopName: json['shopName']?.toString(),
        manager: json['manager']?.toString(),
        sales: (json['sales'] as num?)?.toDouble() ?? 0,
        expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
        profit: (json['profit'] as num?)?.toDouble() ?? 0,
        saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
      );
}

class ExpenseCategoryTotal {
  final String category;
  final double total;

  const ExpenseCategoryTotal({required this.category, required this.total});

  factory ExpenseCategoryTotal.fromJson(Map<String, dynamic> json) => ExpenseCategoryTotal(
        category: json['category']?.toString() ?? 'other',
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
}

class TopProduct {
  final String name;
  final int quantity;
  final double revenue;

  const TopProduct({required this.name, this.quantity = 0, this.revenue = 0});

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        name: json['name']?.toString() ?? 'Product',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      );
}

class DashboardColorStock {
  final String color;
  final int sets;
  final int pieces;

  const DashboardColorStock({required this.color, this.sets = 0, this.pieces = 0});

  factory DashboardColorStock.fromJson(Map<String, dynamic> json) => DashboardColorStock(
        color: json['color']?.toString() ?? '',
        sets: (json['sets'] as num?)?.toInt() ?? 0,
        pieces: (json['pieces'] as num?)?.toInt() ?? 0,
      );
}

class DashboardProduct {
  final String id;
  final String name;
  final String code;
  final String size;
  final String image;
  final int quantity;
  final int lowStockThreshold;
  final String productType;
  final List<DashboardColorStock> colorStocks;

  const DashboardProduct({
    required this.id,
    required this.name,
    this.code = '',
    this.size = '',
    this.image = '',
    this.quantity = 0,
    this.lowStockThreshold = 0,
    this.productType = 'qaleen',
    this.colorStocks = const [],
  });

  bool get isLowStock => quantity <= lowStockThreshold;

  factory DashboardProduct.fromJson(Map<String, dynamic> json) => DashboardProduct(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? 'Product',
        code: json['code']?.toString() ?? '',
        size: json['size']?.toString() ?? '',
        image: json['image']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 0,
        productType: json['productType']?.toString() ?? 'qaleen',
        colorStocks: (json['colorStocks'] as List?)
                ?.map((e) => DashboardColorStock.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class ActivityItem {
  final String type;
  final String title;
  final String subtitle;
  final String? time;

  const ActivityItem({required this.type, this.title = '', this.subtitle = '', this.time});

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        type: json['type']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        time: json['time']?.toString(),
      );
}

class LowStockProduct {
  final String id;
  final String name;
  final String sku;
  final double quantity;
  final double lowStockThreshold;
  final double sellingPrice;

  const LowStockProduct({
    required this.id,
    required this.name,
    this.sku = '',
    this.quantity = 0,
    this.lowStockThreshold = 0,
    this.sellingPrice = 0,
  });

  factory LowStockProduct.fromJson(Map<String, dynamic> json) => LowStockProduct(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? 'Product',
        sku: json['sku']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        lowStockThreshold: (json['lowStockThreshold'] as num?)?.toDouble() ?? 0,
        sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0,
      );
}

class TopCustomer {
  final String name;
  final String phone;
  final double total;
  final int orders;

  const TopCustomer({
    required this.name,
    this.phone = '',
    this.total = 0,
    this.orders = 0,
  });

  factory TopCustomer.fromJson(Map<String, dynamic> json) => TopCustomer(
        name: json['name']?.toString() ?? 'Customer',
        phone: json['phone']?.toString() ?? '',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        orders: (json['orders'] as num?)?.toInt() ?? 0,
      );
}

class ManagerBranch {
  final String id;
  final String name;
  final String address;

  const ManagerBranch({required this.id, required this.name, this.address = ''});

  factory ManagerBranch.fromJson(Map<String, dynamic> json) => ManagerBranch(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
      );
}

class DashboardCards {
  final int totalShops;
  final int totalProducts;
  final int lowStockCount;
  final double totalStockValue;
  final double salesToday;
  final int salesTodayCount;
  final double expensesToday;
  final double monthlyRevenue;
  final double monthlyProfit;
  final double monthlyExpenses;
  final double yearlyRevenue;
  final double yearlyProfit;
  final double yearlyExpenses;

  // Manager (operational) KPI cards — no financial values.
  final int todayOrders;
  final int customerCount;
  final int stockInToday;
  final int stockOutToday;
  final int supplierCount;

  const DashboardCards({
    this.totalShops = 0,
    this.totalProducts = 0,
    this.lowStockCount = 0,
    this.totalStockValue = 0,
    this.salesToday = 0,
    this.salesTodayCount = 0,
    this.expensesToday = 0,
    this.monthlyRevenue = 0,
    this.monthlyProfit = 0,
    this.monthlyExpenses = 0,
    this.yearlyRevenue = 0,
    this.yearlyProfit = 0,
    this.yearlyExpenses = 0,
    this.todayOrders = 0,
    this.customerCount = 0,
    this.stockInToday = 0,
    this.stockOutToday = 0,
    this.supplierCount = 0,
  });

  factory DashboardCards.fromJson(Map<String, dynamic> json) => DashboardCards(
        totalShops: (json['totalShops'] as num?)?.toInt() ?? 0,
        totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
        lowStockCount: (json['lowStockCount'] as num?)?.toInt() ?? 0,
        totalStockValue: (json['totalStockValue'] as num?)?.toDouble() ?? 0,
        salesToday: (json['salesToday'] as num?)?.toDouble() ?? 0,
        salesTodayCount: (json['salesTodayCount'] as num?)?.toInt() ?? 0,
        expensesToday: (json['expensesToday'] as num?)?.toDouble() ?? 0,
        monthlyRevenue: (json['monthlyRevenue'] as num?)?.toDouble() ?? 0,
        monthlyProfit: (json['monthlyProfit'] as num?)?.toDouble() ?? 0,
        monthlyExpenses: (json['monthlyExpenses'] as num?)?.toDouble() ?? 0,
        yearlyRevenue: (json['yearlyRevenue'] as num?)?.toDouble() ?? 0,
        yearlyProfit: (json['yearlyProfit'] as num?)?.toDouble() ?? 0,
        yearlyExpenses: (json['yearlyExpenses'] as num?)?.toDouble() ?? 0,
        todayOrders: (json['todayOrders'] as num?)?.toInt() ?? 0,
        customerCount: (json['customerCount'] as num?)?.toInt() ?? 0,
        stockInToday: (json['stockInToday'] as num?)?.toInt() ?? 0,
        stockOutToday: (json['stockOutToday'] as num?)?.toInt() ?? 0,
        supplierCount: (json['supplierCount'] as num?)?.toInt() ?? 0,
      );
}

class DashboardData {
  final String? role;
  final DashboardCards cards;
  final List<ChartPoint> daily;
  final List<ChartPoint> weekly;
  final List<ChartPoint> monthly;
  final List<ChartPoint> yearly;
  final List<ShopComparison> comparison;
  final List<ExpenseCategoryTotal> expenseBreakdown;
  final List<ShopSummary> shops;
  final List<TopProduct> topProducts;
  final List<TopCustomer> topCustomers;
  final List<LowStockProduct> lowStock;
  final List<ActivityItem> recentActivity;
  final ManagerBranch? branch;
  final List<DashboardProduct> products;

  const DashboardData({
    this.role,
    this.cards = const DashboardCards(),
    this.daily = const [],
    this.weekly = const [],
    this.monthly = const [],
    this.yearly = const [],
    this.comparison = const [],
    this.expenseBreakdown = const [],
    this.shops = const [],
    this.topProducts = const [],
    this.topCustomers = const [],
    this.lowStock = const [],
    this.recentActivity = const [],
    this.branch,
    this.products = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final charts = json['charts'] as Map<String, dynamic>? ?? const {};
    final branchJson = json['branch'];
    return DashboardData(
      role: json['role']?.toString(),
      cards: DashboardCards.fromJson(json['cards'] as Map<String, dynamic>? ?? const {}),
      daily: (charts['daily'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      weekly: (charts['weekly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      monthly: (charts['monthly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      yearly: (charts['yearly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      comparison: (charts['comparison'] as List?)?.map((e) => ShopComparison.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      expenseBreakdown: (charts['expenseBreakdown'] as List?)?.map((e) => ExpenseCategoryTotal.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      shops: (json['shops'] as List?)?.map((e) => ShopSummary.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      topProducts: (json['topProducts'] as List?)?.map((e) => TopProduct.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      topCustomers: (json['topCustomers'] as List?)?.map((e) => TopCustomer.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      lowStock: (json['lowStock'] as List?)?.map((e) => LowStockProduct.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      recentActivity: (json['recentActivity'] as List?)?.map((e) => ActivityItem.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      branch: branchJson is Map<String, dynamic> ? ManagerBranch.fromJson(branchJson) : null,
      products: (json['products'] as List?)?.map((e) => DashboardProduct.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
    );
  }
}

class ShopSummary {
  final String id;
  final String name;
  final String manager;

  const ShopSummary({required this.id, required this.name, this.manager = ''});

  factory ShopSummary.fromJson(Map<String, dynamic> json) => ShopSummary(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? '',
        manager: json['manager']?.toString() ?? '',
      );
}

class ShopOverviewInfo {
  final String id;
  final String name;
  final String address;
  final String contactNumber;
  final String managerName;
  final String managerEmail;
  final String managerPhone;

  const ShopOverviewInfo({
    required this.id,
    required this.name,
    this.address = '',
    this.contactNumber = '',
    this.managerName = '—',
    this.managerEmail = '',
    this.managerPhone = '',
  });

  factory ShopOverviewInfo.fromJson(Map<String, dynamic> json) => ShopOverviewInfo(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        contactNumber: json['contactNumber']?.toString() ?? '',
        managerName: json['managerName']?.toString() ?? '—',
        managerEmail: json['managerEmail']?.toString() ?? '',
        managerPhone: json['managerPhone']?.toString() ?? '',
      );
}

class OverviewCustomer {
  final String id;
  final String name;
  final String phone;
  final double balance;
  final double totalSpent;
  final int purchaseCount;
  final DateTime? lastPurchaseAt;

  const OverviewCustomer({
    required this.id,
    required this.name,
    this.phone = '',
    this.balance = 0,
    this.totalSpent = 0,
    this.purchaseCount = 0,
    this.lastPurchaseAt,
  });

  factory OverviewCustomer.fromJson(Map<String, dynamic> json) => OverviewCustomer(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? 'Customer',
        phone: json['phone']?.toString() ?? '',
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
        purchaseCount: (json['purchaseCount'] as num?)?.toInt() ?? 0,
        lastPurchaseAt: json['lastPurchaseAt'] != null
            ? DateTime.tryParse(json['lastPurchaseAt'].toString())
            : null,
      );
}

class OverviewProduct {
  final String id;
  final String name;
  final String sku;
  final String productType;
  final double quantity;
  final double costPrice;
  final double stockValue;
  final double lowStockThreshold;
  final bool isLowStock;

  const OverviewProduct({
    required this.id,
    required this.name,
    this.sku = '',
    this.productType = 'qaleen',
    this.quantity = 0,
    this.costPrice = 0,
    this.stockValue = 0,
    this.lowStockThreshold = 0,
    this.isLowStock = false,
  });

  factory OverviewProduct.fromJson(Map<String, dynamic> json) => OverviewProduct(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? 'Product',
        sku: json['sku']?.toString() ?? '',
        productType: json['productType']?.toString() ?? 'qaleen',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
        stockValue: (json['stockValue'] as num?)?.toDouble() ?? 0,
        lowStockThreshold: (json['lowStockThreshold'] as num?)?.toDouble() ?? 0,
        isLowStock: json['isLowStock'] == true,
      );
}

class OverviewSale {
  final String id;
  final String invoiceNo;
  final String customerName;
  final double totalAmount;
  final double paidAmount;
  final double dueAmount;
  final DateTime? createdAt;

  const OverviewSale({
    required this.id,
    this.invoiceNo = '',
    this.customerName = 'Walk-in Customer',
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.dueAmount = 0,
    this.createdAt,
  });

  factory OverviewSale.fromJson(Map<String, dynamic> json) => OverviewSale(
        id: (json['id'] ?? json['_id']).toString(),
        invoiceNo: json['invoiceNo']?.toString() ?? '',
        customerName: json['customerName']?.toString() ?? 'Walk-in Customer',
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
        dueAmount: (json['dueAmount'] as num?)?.toDouble() ?? 0,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      );
}

class OverviewExpense {
  final String id;
  final String category;
  final double amount;
  final String description;
  final DateTime? date;

  const OverviewExpense({
    required this.id,
    this.category = 'other',
    this.amount = 0,
    this.description = '',
    this.date,
  });

  factory OverviewExpense.fromJson(Map<String, dynamic> json) => OverviewExpense(
        id: (json['id'] ?? json['_id']).toString(),
        category: json['category']?.toString() ?? 'other',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        description: json['description']?.toString() ?? '',
        date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      );
}

class OverviewManager {
  final String name;
  final String email;
  final String phone;

  const OverviewManager({this.name = '', this.email = '', this.phone = ''});

  factory OverviewManager.fromJson(Map<String, dynamic> json) => OverviewManager(
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
      );
}

class ShopOverview {
  final ShopOverviewInfo shop;
  final ShopOverviewCards cards;
  final List<OverviewCustomer> customers;
  final List<OverviewProduct> products;
  final List<LowStockProduct> lowStock;
  final List<OverviewSale> recentSales;
  final List<OverviewExpense> recentExpenses;
  final List<OverviewManager> managers;

  const ShopOverview({
    this.shop = const ShopOverviewInfo(id: '', name: ''),
    this.cards = const ShopOverviewCards(),
    this.customers = const [],
    this.products = const [],
    this.lowStock = const [],
    this.recentSales = const [],
    this.recentExpenses = const [],
    this.managers = const [],
  });

  factory ShopOverview.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'] as Map<String, dynamic>? ?? const {};
    return ShopOverview(
      shop: ShopOverviewInfo.fromJson(shop),
      cards: ShopOverviewCards.fromJson(json['cards'] as Map<String, dynamic>? ?? const {}),
      customers: (json['customers'] as List?)
              ?.map((e) => OverviewCustomer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      products: (json['products'] as List?)
              ?.map((e) => OverviewProduct.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      lowStock: (json['lowStock'] as List?)
              ?.map((e) => LowStockProduct.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recentSales: (json['recentSales'] as List?)
              ?.map((e) => OverviewSale.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recentExpenses: (json['recentExpenses'] as List?)
              ?.map((e) => OverviewExpense.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      managers: (json['managers'] as List?)
              ?.map((e) => OverviewManager.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class ShopOverviewCards {
  final int totalProducts;
  final double totalStockValue;
  final int lowStockCount;
  final int customerCount;
  final int supplierCount;
  final double receivables;
  final double salesToday;
  final int salesTodayCount;
  final double monthlyRevenue;
  final double monthlyProfit;
  final double monthlyExpenses;

  const ShopOverviewCards({
    this.totalProducts = 0,
    this.totalStockValue = 0,
    this.lowStockCount = 0,
    this.customerCount = 0,
    this.supplierCount = 0,
    this.receivables = 0,
    this.salesToday = 0,
    this.salesTodayCount = 0,
    this.monthlyRevenue = 0,
    this.monthlyProfit = 0,
    this.monthlyExpenses = 0,
  });

  factory ShopOverviewCards.fromJson(Map<String, dynamic> json) => ShopOverviewCards(
        totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
        totalStockValue: (json['totalStockValue'] as num?)?.toDouble() ?? 0,
        lowStockCount: (json['lowStockCount'] as num?)?.toInt() ?? 0,
        customerCount: (json['customerCount'] as num?)?.toInt() ?? 0,
        supplierCount: (json['supplierCount'] as num?)?.toInt() ?? 0,
        receivables: (json['receivables'] as num?)?.toDouble() ?? 0,
        salesToday: (json['salesToday'] as num?)?.toDouble() ?? 0,
        salesTodayCount: (json['salesTodayCount'] as num?)?.toInt() ?? 0,
        monthlyRevenue: (json['monthlyRevenue'] as num?)?.toDouble() ?? 0,
        monthlyProfit: (json['monthlyProfit'] as num?)?.toDouble() ?? 0,
        monthlyExpenses: (json['monthlyExpenses'] as num?)?.toDouble() ?? 0,
      );
}
