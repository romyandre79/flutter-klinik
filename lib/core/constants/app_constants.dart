class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Kreatif - Klinik Offline';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Aplikasi Kasir Klinik Offline - Full Offline, Jalan Tanpa Internet!';

  // Database
  static const String databaseName = 'kreatif_klinik_offline.db';
  static const int databaseVersion = 11;

  // Invoice
  static const String defaultInvoicePrefix = 'Klinik';
  static const int invoiceNumberLength = 6;

  // Default Values
  static const String defaultPaymentMethod = 'cash';
  static const int defaultServiceDuration = 1; // Klinik usually instant, but keep for compatibility
  static const int defaultPageSize = 20;
  static const int recentOrdersLimit = 5;

  // Date Formats
  static const String dateFormat = 'dd MMM yyyy';
  static const String dateTimeFormat = 'dd MMM yyyy HH:mm';
  static const String dateFormatShort = 'dd/MM/yy';
  static const String timeFormat = 'HH:mm';
  static const String invoiceDateFormat = 'yyMMdd';

  // Printer
  static const int printerPaperWidth = 58; // mm
  static const int printerCharPerLine = 32;

  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 20;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;

  // Default Admin Credentials
  static const String defaultOwnerUsername = 'admin';
  static const String defaultOwnerPassword = 'admin';
  static const String defaultOwnerName = 'Administrator';

  // Settings Keys
  static const String keyStoreName = 'store_name';
  static const String keyStoreAddress = 'store_address';
  static const String keyStorePhone = 'store_phone';
  static const String keyInvoicePrefix = 'invoice_prefix';
  static const String keyPrinterAddress = 'printer_address';
  static const String keyLastInvoiceDate = 'last_invoice_date';
  static const String keyLastInvoiceNumber = 'last_invoice_number';

  // Default Store Info
  static const String defaultStoreName = 'Toko Serba Ada';
  static const String defaultStoreAddress = 'Indonesia';
  static const String defaultStorePhone = '-';

  static const bool isDemoMode = true;
}
