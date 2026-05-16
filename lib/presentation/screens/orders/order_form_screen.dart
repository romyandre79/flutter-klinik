import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kreatif_klinik/core/constants/colors.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/core/utils/currency_formatter.dart';
import 'package:kreatif_klinik/core/utils/thousand_separator_formatter.dart';
import 'package:kreatif_klinik/data/models/customer.dart';
import 'package:kreatif_klinik/data/models/order_item.dart';
import 'package:kreatif_klinik/data/models/payment.dart';
import 'package:kreatif_klinik/data/models/product.dart';
import 'package:kreatif_klinik/data/models/order.dart';
import 'package:kreatif_klinik/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_klinik/logic/cubits/customer/customer_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/customer/customer_state.dart';
import 'package:kreatif_klinik/logic/cubits/order/order_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/order/order_state.dart';
import 'package:kreatif_klinik/logic/cubits/product/product_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/product/product_state.dart';
import 'package:kreatif_klinik/logic/cubits/unit/unit_cubit.dart';
import 'package:kreatif_klinik/presentation/screens/orders/sales_order_item_editor.dart';

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _paymentController = TextEditingController();

  DateTime _dueDate = DateTime.now();
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  OrderStatus _selectedStatus = OrderStatus.pending;
  bool _isLoading = false;

  // Selected customer
  Customer? _selectedCustomer;

  // Order items
  final List<OrderItem> _items = [];

  int get _totalPrice {
    return _items.fold(0, (sum, item) => sum + item.subtotal);
  }

  @override
  void initState() {
    super.initState();
    // Load products and units when screen opens
    context.read<ProductCubit>().loadProducts();
    // Assuming UnitCubit is provided in the parent route or we need to load it here?
    // It is provided in OrderListScreen navigation (MultiBlocProvider).
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  void _addItem() async {
    final productState = context.read<ProductCubit>().state;
    List<Product> products = [];
    if (productState is ProductLoaded) {
      products = productState.products;
    }

    final newItem = await Navigator.push<OrderItem>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<UnitCubit>(), // Pass unit cubit
          child: SalesOrderItemEditor(products: products),
        ),
      ),
    );

    if (!mounted) return;

    if (newItem != null) {
      setState(() {
        // Find if item already exists with same Product ID and Unit
        final existingIndex = _items.indexWhere((item) =>
            item.productId != null &&
            item.productId == newItem.productId &&
            item.unit == newItem.unit);

        if (existingIndex != -1) {
          final existingItem = _items[existingIndex];
          final newQuantity = existingItem.quantity + newItem.quantity;

          _items[existingIndex] = existingItem.copyWith(
            quantity: newQuantity,
            subtotal: (newQuantity * existingItem.pricePerUnit).round(),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${newItem.serviceName} jumlah bertambah menjadi $newQuantity ${newItem.unit}'),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          _items.add(newItem);
        }
      });
    }
  }

  void _editItem(int index) async {
    final productState = context.read<ProductCubit>().state;
    List<Product> products = [];
    if (productState is ProductLoaded) {
      products = productState.products;
    }

    final updatedItem = await Navigator.push<OrderItem>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<UnitCubit>(),
          child: SalesOrderItemEditor(
            products: products,
            existingItem: _items[index],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (updatedItem != null) {
      setState(() {
        _items[index] = updatedItem;
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerNameController.text = customer.name;
      _customerPhoneController.text = customer.phone ?? '';
    });
  }

  void _clearSelectedCustomer() {
    setState(() {
      _selectedCustomer = null;
      _customerNameController.clear();
      _customerPhoneController.clear();
    });
  }

  void _showCustomerSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => BlocProvider.value(
        value: context.read<CustomerCubit>()..loadCustomers(),
        child: _CustomerSearchSheet(
          onCustomerSelected: (customer) {
            Navigator.pop(bottomSheetContext);
            _selectCustomer(customer);
          },
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 item'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final payment = ThousandSeparatorFormatter.parseToInt(_paymentController.text);

    // Validate Status 'Selesai' must be fully paid
    if (_selectedStatus == OrderStatus.done && payment < _totalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan harus lunas jika status Selesai'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Jika bayar lebih dari total, tampilkan dialog konfirmasi kembalian
    if (payment > _totalPrice) {
      _showChangeConfirmationDialog(payment);
    } else {
      _submitOrder(payment);
    }
  }

  void _showChangeConfirmationDialog(int payment) {
    final change = payment - _totalPrice;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppThemeColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.payments_outlined,
                color: AppThemeColors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Konfirmasi Pembayaran',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppThemeColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildPaymentRow('Total', CurrencyFormatter.format(_totalPrice)),
                  const SizedBox(height: 8),
                  _buildPaymentRow('Bayar', CurrencyFormatter.format(payment)),
                  const Divider(height: 16),
                  _buildPaymentRow(
                    'Kembalian',
                    CurrencyFormatter.format(change),
                    valueColor: AppThemeColors.success,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pembayaran akan dicatat sebagai LUNAS',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppThemeColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: AppThemeColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _submitOrder(payment);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Konfirmasi',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? AppThemeColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _submitOrder(int payment) {
    final authState = context.read<AuthCubit>().state;
    final userId = authState is AuthAuthenticated ? authState.user.id : null;

    // Items are already OrderItem
    final orderItems = _items;

    context.read<OrderCubit>().createOrder(
          customerName: _customerNameController.text,
          customerPhone: _customerPhoneController.text.isNotEmpty
              ? _customerPhoneController.text
              : null,
          customerId: _selectedCustomer?.id,
          items: orderItems,
          dueDate: _dueDate,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
          createdBy: userId,
          initialPayment: payment,
          paymentMethod: _paymentMethod,
          status: _selectedStatus,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is OrderLoading) {
          setState(() => _isLoading = true);
        } else {
          setState(() => _isLoading = false);
        }

        if (state is OrderCreated) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Penjualan ${state.order.invoiceNo} berhasil dibuat'),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is OrderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: BlocBuilder<ProductCubit, ProductState>(
        builder: (context, productState) {
          if (productState is ProductLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Penjualan Baru'),
              actions: [
              ],
            ),
            body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Customer Section
                    _buildSectionTitle('Informasi Pelanggan'),
                    const SizedBox(height: 12),

                    // Customer selection card
                    if (_selectedCustomer != null) ...[
                      _buildSelectedCustomerCard(),
                      const SizedBox(height: 12),
                    ] else ...[
                      // Search existing customer button
                      InkWell(
                        onTap: _showCustomerSearchDialog,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppThemeColors.primarySurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppThemeColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppThemeColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.person_search,
                                  color: AppThemeColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pilih Pelanggan',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        color: AppThemeColors.primary,
                                      ),
                                    ),
                                    Text(
                                      'Cari dari daftar pelanggan',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppThemeColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: AppThemeColors.primary,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Divider with "atau"
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppThemeColors.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'atau input manual',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppThemeColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: AppThemeColors.border)),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _customerNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Pelanggan *',
                        prefixIcon: const Icon(Icons.person_outline),
                        enabled: _selectedCustomer == null,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Nama tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerPhoneController,
                      decoration: InputDecoration(
                        labelText: 'No. HP (Opsional)',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        hintText: '08xx-xxxx-xxxx',
                        enabled: _selectedCustomer == null,
                      ),
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 24),

                    // Items Section (List)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Daftar Item'),
                          TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Tambah'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppThemeColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppThemeColors.border),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.shopping_basket_outlined,
                                size: 40,
                                color: AppThemeColors.textSecondary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Belum ada item',
                                style: GoogleFonts.poppins(
                                  color: AppThemeColors.textSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: _addItem,
                                child: const Text('Tambah Item Baru'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              title: Text(
                                item.serviceName,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.pricePerUnit)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppThemeColors.textSecondary,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: AppThemeColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                    onPressed: () => _editItem(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                    onPressed: () => _removeItem(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 24),

                    // Due Date
                    _buildSectionTitle('Tanggal Ambil (Estimasi Selesai)'),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDueDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppThemeColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: AppThemeColors.primary),
                            const SizedBox(width: 12),
                            Text(
                              '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                              style: GoogleFonts.poppins(fontSize: 16),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Notes
                    _buildSectionTitle('Catatan (Opsional)'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Catatan',
                        prefixIcon: Icon(Icons.note_outlined),
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 24),

                    // Payment Section
                    _buildSectionTitle('Pembayaran'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _paymentController,
                            decoration: const InputDecoration(
                              labelText: 'Bayar (DP/Lunas)',
                              prefixText: 'Rp ',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [ThousandSeparatorFormatter()],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<PaymentMethod>(
                            initialValue: _paymentMethod,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Metode',
                            ),
                            items: PaymentMethod.values.map((method) {
                              return DropdownMenuItem(
                                value: method,
                                child: Text(
                                  method.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _paymentMethod = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Status Section
                    _buildSectionTitle('Status Pesanan'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<OrderStatus>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.info_outline),
                        border: OutlineInputBorder(),
                      ),
                      items: OrderStatus.values.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status.displayName),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedStatus = v);
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              
              // Bottom Bar (Total & Submit)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppThemeColors.primarySurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(_totalPrice),
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppThemeColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Buat Penjualan',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildSelectedCustomerCard() {
    final customer = _selectedCustomer!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppThemeColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppThemeColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.person,
              color: AppThemeColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppThemeColors.textPrimary,
                  ),
                ),
                if (customer.phone != null && customer.phone!.isNotEmpty)
                  Text(
                    customer.phone!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppThemeColors.textSecondary,
                    ),
                  ),
                if (customer.totalOrders > 0)
                  Text(
                    '${customer.totalOrders} order sebelumnya',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppThemeColors.success,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearSelectedCustomer,
            icon: Icon(
              Icons.close,
              color: AppThemeColors.textSecondary,
              size: 20,
            ),
            tooltip: 'Hapus pilihan',
          ),
        ],
      ),
    );
  }
}

// Customer Search Bottom Sheet
class _CustomerSearchSheet extends StatefulWidget {
  final Function(Customer) onCustomerSelected;

  const _CustomerSearchSheet({required this.onCustomerSelected});

  @override
  State<_CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends State<_CustomerSearchSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      context.read<CustomerCubit>().loadCustomers();
    } else {
      context.read<CustomerCubit>().searchCustomers(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppThemeColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Pilih Pelanggan',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama atau nomor HP...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppThemeColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {});
                _performSearch(value);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Customer list
          Expanded(
            child: BlocBuilder<CustomerCubit, CustomerState>(
              builder: (context, state) {
                final customers = context.read<CustomerCubit>().customers;

                if (state is CustomerLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppThemeColors.primary,
                    ),
                  );
                }

                if (customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 48,
                          color: AppThemeColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Belum ada pelanggan'
                              : 'Pelanggan tidak ditemukan',
                          style: GoogleFonts.poppins(
                            color: AppThemeColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: customers.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: AppThemeColors.border,
                  ),
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppThemeColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppThemeColors.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        customer.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: customer.phone != null && customer.phone!.isNotEmpty
                          ? Text(
                              customer.phone!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppThemeColors.textSecondary,
                              ),
                            )
                          : null,
                      trailing: customer.totalOrders > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppThemeColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${customer.totalOrders} order',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppThemeColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : null,
                      onTap: () => widget.onCustomerSelected(customer),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
