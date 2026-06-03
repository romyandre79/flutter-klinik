import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/core/services/notification_service.dart';
import 'package:kreatif_pos/core/utils/invoice_generator.dart';
import 'package:kreatif_pos/data/models/order.dart';
import 'package:kreatif_pos/data/models/order_item.dart';
import 'package:kreatif_pos/data/models/payment.dart';
import 'package:kreatif_pos/data/repositories/customer_repository.dart';
import 'package:kreatif_pos/data/repositories/order_repository.dart';
import 'package:kreatif_pos/data/repositories/payment_repository.dart';
import 'package:kreatif_pos/data/repositories/product_repository.dart';
import 'package:kreatif_pos/logic/cubits/order/order_state.dart';
import 'package:kreatif_pos/core/constants/app_constants.dart';

class OrderCubit extends Cubit<OrderState> {
  final OrderRepository _orderRepository;
  final CustomerRepository _customerRepository;
  final ProductRepository _productRepository;
  final PaymentRepository _paymentRepository;

  List<Order> _orders = [];
  OrderStatus? _currentFilter;

  OrderCubit({
    required OrderRepository orderRepository,
    required CustomerRepository customerRepository,
    required ProductRepository productRepository,
    required PaymentRepository paymentRepository,
  })  : _orderRepository = orderRepository,
        _customerRepository = customerRepository,
        _productRepository = productRepository,
        _paymentRepository = paymentRepository,
        super(const OrderInitial());

  List<Order> get orders => _orders;

  /// Load orders
  Future<void> loadOrders({OrderStatus? status}) async {
    _currentFilter = status;
    emit(const OrderLoading());

    try {
      _orders = await _orderRepository.getAllOrders(status: status);
      emit(OrderLoaded(_orders));
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Load more orders (pagination)
  Future<void> loadMoreOrders() async {
    if (state is OrderLoaded) {
      final loadedState = state as OrderLoaded;
      if (loadedState.isLoadingMore || !loadedState.hasMore) return;

      emit(loadedState.copyWith(isLoadingMore: true));

      try {
         final currentLength = _orders.length;
         final newOrders = await _orderRepository.getAllOrders(
           status: _currentFilter,
           offset: currentLength,
           limit: 20,
         );

         if (newOrders.isEmpty) {
           emit(loadedState.copyWith(isLoadingMore: false, hasMore: false));
         } else {
           _orders.addAll(newOrders);
           emit(OrderLoaded(_orders));
         }
      } catch (e) {
        // Keep existing state but maybe show toast? 
        // For simplicity, just stop loading more
        emit(loadedState.copyWith(isLoadingMore: false));
      }
    }
  }

  /// Create new order
  Future<void> createOrder({
    required String customerName,
    String? customerPhone,
    int? customerId,
    required List<OrderItem> items,
    DateTime? dueDate,
    String? notes,
    String? nomorPolisi,
    int? createdBy,
    int initialPayment = 0,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    OrderStatus status = OrderStatus.pending,
    int totalDiscount = 0,
  }) async {
    if (AppConstants.isDemoMode) {
      final allOrders = await _orderRepository.getAllOrders();
      if (allOrders.length >= 10) {
        emit(const OrderError('Anda telah melebihi batas transaksi aplikasi demo, silakan beli hubungi Sales Kreatif atau ke 081932701147'));
        return;
      }
    }

    emit(const OrderLoading());

    try {
      // Validate
      if (customerName.trim().isEmpty) {
        emit(const OrderError('Nama customer tidak boleh kosong'));
        return;
      }
      if (items.isEmpty) {
        emit(const OrderError('Minimal 1 item harus dipilih'));
        return;
      }

      // If manual input (no customerId), save customer to database
      int? finalCustomerId = customerId;
      if (finalCustomerId == null) {
        try {
          final customer = customerPhone != null && customerPhone.trim().isNotEmpty
              ? await _customerRepository.getOrCreateByPhone(
                  name: customerName,
                  phone: customerPhone,
                )
              : await _customerRepository.getOrCreateByName(
                  name: customerName,
                );
          finalCustomerId = customer.id;
        } catch (e) {
          // If customer creation fails, continue without customerId
          // This allows order creation even if customer save fails
        }
      }

      int totalGross = 0;
      int itemDiscounts = 0;
      double totalWeight = 0;
      int totalItems = items.length;

      for (final item in items) {
        totalWeight += item.quantity;
        totalGross += (item.pricePerUnit * item.quantity).round();
        itemDiscounts += item.discount;
      }
      
      final combinedDiscount = itemDiscounts + totalDiscount;
      final totalPrice = totalGross - combinedDiscount;

      // Generate invoice
      final invoiceNo = await InvoiceGenerator.generate();

      // Yang dicatat sebagai "paid" di order adalah jumlah yang diterima
      final paidAmount = initialPayment;

      // Create order
      final order = Order(
        invoiceNo: invoiceNo,
        customerId: finalCustomerId,
        customerName: customerName.trim(),
        customerPhone: customerPhone?.trim(),
        orderDate: DateTime.now(),
        dueDate: dueDate,
        status: status,
        totalItems: totalItems,
        totalWeight: totalWeight,
        totalPrice: totalPrice,
        totalDiscount: combinedDiscount,
        paid: paidAmount,
        notes: notes?.trim(),
        nomorPolisi: nomorPolisi?.trim().isEmpty == true ? null : nomorPolisi?.trim(),
        createdBy: createdBy,
      );

      // Prepare initial payment if any
      Payment? payment;
      if (initialPayment > 0) {
        // Hitung kembalian untuk pembayaran awal
        final change = initialPayment > totalPrice ? initialPayment - totalPrice : 0;
        
        payment = Payment(
          orderId: 0, // Will be set after order creation
          amount: initialPayment, // Simpan jumlah bayar apa adanya
          change: change, // Simpan kembalian
          paymentDate: DateTime.now(),
          paymentMethod: paymentMethod,
          receivedBy: createdBy,
        );
      }

      // Save to database
      final createdOrder = await _orderRepository.createOrder(
        order: order,
        items: items.map((item) => item.copyWith(orderId: 0)).toList(),
        initialPayment: payment,
      );

      // Schedule notification
      try {
        await NotificationService().scheduleOrderReminder(createdOrder);
      } catch (_) {
        // Ignore notification errors
      }

      emit(OrderCreated(createdOrder));

      // Reload orders
      await loadOrders(status: _currentFilter);
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Update order status
  Future<void> updateStatus(int orderId, OrderStatus newStatus) async {
    emit(const OrderLoading());

    try {
      await _orderRepository.updateOrderStatus(orderId, newStatus);
      
      // Cancel reminder if order is done
      if (newStatus == OrderStatus.done) {
        try {
          await NotificationService().cancelOrderReminders(orderId);
        } catch (_) {
          // Ignore notification errors
        }
      }

      emit(const OrderOperationSuccess('Status berhasil diubah'));

      // Reload orders
      await loadOrders(status: _currentFilter);
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Add payment to order
  /// Menyimpan pembayaran apa adanya beserta kembalian
  Future<void> addPayment({
    required int orderId,
    required int amount,
    required PaymentMethod method,
    String? notes,
    int? receivedBy,
  }) async {
    emit(const OrderLoading());

    try {
      // Get order to check remaining payment
      final order = await _orderRepository.getOrderById(orderId);
      if (order == null) {
        emit(const OrderError('Penjualan tidak ditemukan'));
        return;
      }

      final remaining = order.remainingPayment;
      if (remaining <= 0) {
        emit(const OrderError('Penjualan sudah lunas'));
        return;
      }

      // Hitung kembalian jika bayar lebih dari sisa
      final change = amount > remaining ? amount - remaining : 0;

      final payment = Payment(
        orderId: orderId,
        amount: amount, // Simpan apa adanya
        change: change, // Simpan kembalian
        paymentDate: DateTime.now(),
        paymentMethod: method,
        notes: notes,
        receivedBy: receivedBy,
      );

      await _paymentRepository.addPayment(payment);
      emit(const OrderOperationSuccess('Pembayaran berhasil ditambahkan'));

      // Reload order detail
      await loadOrderDetail(orderId);
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }
  
  /// Load order detail
  Future<void> loadOrderDetail(int orderId) async {
    emit(const OrderLoading());

    try {
      final order = await _orderRepository.getOrderById(orderId);
      if (order != null) {
        emit(OrderDetailLoaded(order));
      } else {
        emit(const OrderError('Penjualan tidak ditemukan'));
      }
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Delete order
  Future<void> deleteOrder(int orderId) async {
    emit(const OrderLoading());

    try {
      await _orderRepository.deleteOrder(orderId);
      emit(const OrderOperationSuccess('Penjualan berhasil dihapus'));

      // Reload orders
      await loadOrders(status: _currentFilter);
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Search orders
  Future<void> searchOrders(String query) async {
    emit(const OrderLoading());

    try {
      if (query.trim().isEmpty) {
        await loadOrders(status: _currentFilter);
        return;
      }

      _orders = await _orderRepository.searchOrders(query);
      emit(OrderLoaded(_orders));
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
