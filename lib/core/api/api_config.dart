class ApiConfig {
  static const String baseUrl = 'http://your-api-url.com'; // Replace with actual URL
  static const String executeFlowEndpoint = '/api/admin/execute-flow';
  
  // Deprecated REST Endpoints (Using Flow instead)
  @Deprecated('Use executeFlow with pos_login')
  static const String loginEndpoint = '/login';
  @Deprecated('Use executeFlow with pos_get_products')
  static const String productsEndpoint = '/products';
  @Deprecated('Use executeFlow with pos_get_customers')
  static const String customersEndpoint = '/customers';
  @Deprecated('Use executeFlow with pos_sync_orders')
  static const String ordersEndpoint = '/orders';
  @Deprecated('Use executeFlow')
  static const String syncEndpoint = '/sync';
}
