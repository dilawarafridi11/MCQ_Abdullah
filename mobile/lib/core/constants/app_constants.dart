class AppConstants {
  AppConstants._();

  static const String appName = 'MCQ';
  static const String appFullName = 'Muallim Carpets';
  static const String appTagline = 'Business Management System';
  static const String appVersion = '1.0.0';

  // Server base URL.
  // Local backend (Android emulator routes 10.0.2.2 to the host machine's localhost).
  static const String baseUrl = 'http://10.0.2.2:5000/api';

  static const String currencySymbol = 'Rs.';

  static const List<String> paymentMethods = ['cash', 'bank', 'easypaisa', 'jazzcash', 'credit'];
  static const List<String> expenseCategories = [
    'rent',
    'electricity',
    'salary',
    'fuel',
    'internet',
    'maintenance',
    'marketing',
    'other',
  ];
  static const List<String> reportPeriods = ['today', 'week', 'month', 'year'];
  static const List<String> auditModules = [
    'all',
    'auth',
    'products',
    'categories',
    'inventory',
    'sales',
    'expenses',
    'shops',
    'users',
    'reports',
    'customers',
    'suppliers',
  ];

  static const Map<String, String> paymentMethodLabels = {
    'cash': 'Cash',
    'bank': 'Bank',
    'easypaisa': 'EasyPaisa',
    'jazzcash': 'JazzCash',
    'credit': 'Credit',
  };

  static const Map<String, String> expenseCategoryLabels = {
    'rent': 'Rent',
    'electricity': 'Electricity',
    'salary': 'Salary',
    'fuel': 'Fuel',
    'internet': 'Internet',
    'maintenance': 'Maintenance',
    'marketing': 'Marketing',
    'other': 'Other',
  };

  static const Map<String, String> actionLabels = {
    'CREATE_PRODUCT': 'Product Created',
    'UPDATE_PRODUCT': 'Product Updated',
    'DELETE_PRODUCT': 'Product Deleted',
    'RESTORE_PRODUCT': 'Product Restored',
    'CREATE_CATEGORY': 'Category Created',
    'UPDATE_CATEGORY': 'Category Updated',
    'DELETE_CATEGORY': 'Category Deleted',
    'RESTORE_CATEGORY': 'Category Restored',
    'STOCK_IN': 'Stock In',
    'STOCK_OUT': 'Stock Out',
    'STOCK_TRANSFER': 'Stock Transfer',
    'CREATE_SALE': 'Sale Created',
    'UPDATE_SALE': 'Sale Updated',
    'DELETE_SALE': 'Sale Deleted',
    'RESTORE_SALE': 'Sale Restored',
    'CREATE_EXPENSE': 'Expense Created',
    'UPDATE_EXPENSE': 'Expense Updated',
    'DELETE_EXPENSE': 'Expense Deleted',
    'RESTORE_EXPENSE': 'Expense Restored',
    'CREATE_USER': 'User Created',
    'UPDATE_USER': 'User Updated',
    'LOGIN': 'Login',
    'LOGOUT': 'Logout',
    'REPORT_DOWNLOAD': 'Report Downloaded',
    'CREATE_CUSTOMER': 'Customer Added',
    'UPDATE_CUSTOMER': 'Customer Updated',
    'DELETE_CUSTOMER': 'Customer Deleted',
    'RESTORE_CUSTOMER': 'Customer Restored',
    'CREATE_SUPPLIER': 'Supplier Added',
    'UPDATE_SUPPLIER': 'Supplier Updated',
    'DELETE_SUPPLIER': 'Supplier Deleted',
    'RESTORE_SUPPLIER': 'Supplier Restored',
  };
}
