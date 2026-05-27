import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/core/theme/app_theme.dart';
import 'package:kreatif_pos/core/utils/currency_formatter.dart';
import 'package:kreatif_pos/data/models/order_item.dart';
import 'package:kreatif_pos/data/models/product_unit.dart';

import 'package:kreatif_pos/data/models/payment.dart';
import 'package:kreatif_pos/logic/cubits/order/order_cubit.dart';
import 'package:kreatif_pos/logic/cubits/order/order_state.dart';
import 'package:kreatif_pos/logic/cubits/pos/pos_cubit.dart';
import 'package:kreatif_pos/logic/cubits/pos/pos_state.dart';
import 'package:kreatif_pos/data/models/customer.dart';
import 'package:kreatif_pos/data/models/order.dart'; 
import 'package:kreatif_pos/data/models/cart_item.dart';
import 'package:kreatif_pos/presentation/widgets/payment_dialog.dart';
import 'package:kreatif_pos/presentation/widgets/searchable_customer_picker.dart';
import 'package:kreatif_pos/presentation/widgets/searchable_unit_picker.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  void _handleCharge(BuildContext context, int totalAmount) {
    // Capture the cubit from the current context
    final posCubit = context.read<PosCubit>();
    final state = posCubit.state;

    if (state is! PosLoaded) return;

    // Validate Status and Stock
    for (final item in state.cartItems) {
      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jumlah item tidak boleh 0'),
            backgroundColor: AppThemeColors.error,
          ),
        );
        return;
      }

      if (item.product.isGoods) {
        final currentStock = item.product.stock ?? 0;
        // Convert sold quantity to base unit before comparing with products.stock
        final multiplier = item.selectedUnit?.multiplier ?? 1.0;
        final quantityInBaseUnit = item.quantity * multiplier;
        if (quantityInBaseUnit > currentStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Stok ${item.product.name} tidak mencukupi (Sisa: ${currentStock.toStringAsFixed(2)})'),
              backgroundColor: AppThemeColors.error,
            ),
          );
          return;
        }
      }
    }
    
    showDialog(
      context: context,
      builder: (ctx) => PaymentDialog(
        totalAmount: totalAmount,
        onConfirm: (paidAmount, paymentMethod, status, dueDate) {
          // Use the captured cubit
          _processCheckout(context, posCubit, paidAmount, paymentMethod, status, dueDate);
        },
      ),
    );
  }

  void _processCheckout(
    BuildContext context,
    PosCubit posCubit,
    int paidAmount,
    PaymentMethod paymentMethod,
    OrderStatus status,
    DateTime? dueDate,
  ) {
    final posState = posCubit.state;
    if (posState is! PosLoaded) return;

    final cartItems = posState.cartItems;
    if (cartItems.isEmpty) return;

    // Convert CartItems to OrderItems
    final orderItems = cartItems.map((item) {
      return OrderItem(
        orderId: 0, // Placeholder
        productId: item.product.id,
        unitId: item.selectedUnit?.id,
        serviceName: item.product.name,
        quantity: item.quantity.toDouble(),
        unit: item.selectedUnit?.unitName ?? item.product.unit,
        pricePerUnit: item.selectedUnit?.price ?? item.product.price,
        discount: item.discount,
        subtotal: item.subtotal,
      );
    }).toList();

    context.read<OrderCubit>().createOrder(
      customerName: posState.customerName, 
      customerId: posState.selectedCustomer?.id,
      customerPhone: posState.selectedCustomer?.phone,
      items: orderItems,
      dueDate: dueDate, // Pass the selected due date
      initialPayment: paidAmount,
      paymentMethod: paymentMethod,
      status: status,
      totalDiscount: posState.orderDiscount,
      createdBy: 1, // TODO: Get from AuthCubit
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is OrderCreated) {
          // Clear cart then reload products so stock reflects the completed sale
          context.read<PosCubit>()
            ..clearCart()
            ..loadProducts();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Penjualan ${state.order.invoiceNo} berhasil dibuat'),
              backgroundColor: AppThemeColors.success,
            ),
          );
        } else if (state is OrderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppThemeColors.error,
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            left: BorderSide(color: AppThemeColors.border),
          ),
        ),
        child: Column(
          children: [
            // Customer Selector
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: _CustomerSelector(),
            ),
            
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppThemeColors.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daftar Penjualan',
                    style: AppTypography.titleMedium,
                  ),

                ],
              ),
            ),
            
            // Cart Items List
            Expanded(
              child: BlocBuilder<PosCubit, PosState>(
                builder: (context, state) {
                  if (state is PosLoaded) {
                    if (state.cartItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              size: 48,
                              color: AppThemeColors.disabled,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Keranjang Masih Kosong',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppThemeColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: state.cartItems.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = state.cartItems[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Quantity Controls
                              Column(
                                children: [
                                  InkWell(
                                    onTap: () => context.read<PosCubit>().addToCart(item.product, unit: item.selectedUnit),
                                    child: const Icon(Icons.add_circle, color: AppThemeColors.primary, size: 20),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text('${item.quantity}', style: AppTypography.labelLarge),
                                  ),
                                  InkWell(
                                    onTap: () => context.read<PosCubit>().removeFromCart(item),
                                    child: const Icon(Icons.remove_circle, color: AppThemeColors.error, size: 20),
                                  ),
                                ],
                              ),
                              const SizedBox(width: AppSpacing.md),
                              // Thumbnail
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppThemeColors.primarySurface.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                                  image: item.product.imageUrl != null && File(item.product.imageUrl!).existsSync()
                                      ? DecorationImage(
                                          image: FileImage(File(item.product.imageUrl!)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: item.product.imageUrl != null && File(item.product.imageUrl!).existsSync()
                                    ? null
                                    : Center(
                                        child: Text(
                                          item.product.name.isNotEmpty ? item.product.name[0].toUpperCase() : '?',
                                          style: AppTypography.labelLarge.copyWith(
                                            color: AppThemeColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: AppTypography.bodyMedium),
                                    Row(
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(item.effectivePrice),
                                          style: AppTypography.bodySmall,
                                        ),
                                      ],
                                    ),
                                    // Unit Selection
                                    if (item.product.units.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: SearchableUnitPicker(
                                          label: 'Satuan',
                                          selectedUnit: item.selectedUnit?.unitName ?? item.product.unit,
                                          manualUnits: item.product.units.map((u) => u.unitName).toList(),
                                          onUnitSelected: (unitName) {
                                            final newUnit = item.product.units.firstWhere((u) => u.unitName == unitName);
                                            context.read<PosCubit>().updateUnit(item, newUnit);
                                          },
                                        ),
                                      ),
                                    // Discount Input Trigger
                                    InkWell(
                                      onTap: () => _showItemDiscountDialog(context, item),
                                      child: Text(
                                        'Diskon: ${CurrencyFormatter.format(item.discount)}',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppThemeColors.primary,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Gross Total
                              Text(
                                CurrencyFormatter.format(item.grossTotal),
                                style: AppTypography.labelLarge,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),

            // Footer (Total & Checkout)
            BlocBuilder<PosCubit, PosState>(
              builder: (context, state) {
                int grossTotal = 0;
                int totalDiscount = 0;
                int grandTotal = 0;
                
                if (state is PosLoaded) {
                   grossTotal = state.totalAmount;
                   totalDiscount = state.totalDiscount;
                   grandTotal = state.grandTotal;
                }

                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Total Nilai', grossTotal),
                      _buildSummaryRow(
                        'Diskon Tambahan', 
                        state is PosLoaded ? state.orderDiscount : 0,
                        isClickable: true,
                        onTap: () => _showOrderDiscountDialog(context, state as PosLoaded),
                      ),
                      _buildSummaryRow('Total Diskon', totalDiscount, color: AppThemeColors.error),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Bayar', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            CurrencyFormatter.format(grandTotal),
                            style: AppTypography.titleLarge.copyWith(
                              color: AppThemeColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          ),
                          onPressed: grandTotal > 0 
                            ? () => _handleCharge(context, grandTotal)
                            : null,
                          child: Text(
                             grandTotal > 0 ? 'Bayar ${CurrencyFormatter.format(grandTotal)}' : 'Bayar',
                             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, int value, {Color? color, bool isClickable = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label, 
              style: AppTypography.bodySmall.copyWith(
                color: isClickable ? AppThemeColors.primary : AppThemeColors.textSecondary,
                decoration: isClickable ? TextDecoration.underline : null,
              )
            ),
            Text(
              CurrencyFormatter.format(value),
              style: AppTypography.bodySmall.copyWith(
                color: color ?? AppThemeColors.textPrimary,
                fontWeight: color != null ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDiscountDialog(BuildContext context, CartItem item) {
    final controller = TextEditingController(text: item.discount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Diskon ${item.product.name} (Rp)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Masukkan nilai Rupiah',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              context.read<PosCubit>().updateItemDiscount(item, val);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showOrderDiscountDialog(BuildContext context, PosLoaded state) {
    final controller = TextEditingController(text: state.orderDiscount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diskon Tambahan Pesanan (Rp)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Masukkan nilai Rupiah',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              context.read<PosCubit>().updateOrderDiscount(val);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _CustomerSelector extends StatelessWidget {
  const _CustomerSelector();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        if (state is! PosLoaded) return const SizedBox.shrink();

        return SearchableCustomerPicker(
          selectedCustomer: state.selectedCustomer,
          onCustomerSelected: (customer) {
            context.read<PosCubit>().selectCustomer(customer);
          },
          hint: 'Cari Pelanggan...',
        );
      },
    );
  }
}
