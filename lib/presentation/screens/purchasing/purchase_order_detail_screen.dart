import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/core/utils/currency_formatter.dart';
import 'package:kreatif_klinik/core/utils/date_formatter.dart';
import 'package:kreatif_klinik/data/models/purchase_order.dart';
import 'package:kreatif_klinik/data/models/user.dart';
import 'package:kreatif_klinik/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_klinik/logic/cubits/product/product_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/purchase_order/purchase_order_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/purchase_order/purchase_order_state.dart';
import 'package:kreatif_klinik/presentation/screens/purchasing/receive_order_screen.dart';

class PurchaseOrderDetailScreen extends StatelessWidget {
  final PurchaseOrder order;

  const PurchaseOrderDetailScreen({super.key, required this.order});

  bool _isOwner(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    return authState is AuthAuthenticated && authState.user.role == UserRole.owner;
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _isOwner(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Pembelian #${order.id}'),
        actions: [
          if (isOwner && order.status != 'pending')
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: 'Hapus Pembelian',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Pembelian?'),
                    content: Text(order.status == 'received'
                        ? 'Apakah Anda yakin ingin menghapus pembelian ini? Stok produk akan otomatis dikurangi kembali.'
                        : 'Apakah Anda yakin ingin menghapus pembelian ini?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.read<PurchaseOrderCubit>().deletePurchaseOrder(order.id!);
                        },
                        child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: BlocListener<PurchaseOrderCubit, PurchaseOrderState>(
        listener: (context, state) {
          if (state is PoOperationSuccess) {
            // Refresh product stock after PO is received/deleted
            context.read<ProductCubit>().loadProducts();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
            Navigator.pop(context);
          } else if (state is PoError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withValues(alpha: 0.1),
                        border: Border.all(color: _getStatusColor(order.status)),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        children: [
                          Text(
                            order.statusDisplay,
                            style: TextStyle(
                              color: _getStatusColor(order.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dibuat: ${DateFormatter.formatDateTime(order.orderDate)}',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Supplier Info
                    _buildSectionTitle('Supplier'),
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.store)),
                        title: Text(order.supplier?.name ?? 'Unknown Supplier'),
                        subtitle: order.supplier?.phone != null ? Text(order.supplier!.phone!) : null,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Info Lain
                    _buildSectionTitle('Informasi'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            _buildInfoRow('Tgl Kedatangan', order.expectedDate != null ? DateFormatter.formatDate(order.expectedDate!) : '-'),
                            const Divider(),
                            _buildInfoRow('Catatan', order.notes?.isNotEmpty == true ? order.notes! : '-'),
                            if (order.status == 'received') ...[
                              const Divider(),
                              _buildInfoRow(
                                'No. Faktur', 
                                order.noFaktur?.isNotEmpty == true ? order.noFaktur! : '-',
                              ),
                              const Divider(),
                              _buildInfoRow(
                                'Tgl. Faktur', 
                                order.tglFaktur?.isNotEmpty == true && DateTime.tryParse(order.tglFaktur!) != null
                                    ? DateFormatter.formatDate(DateTime.parse(order.tglFaktur!)) 
                                    : '-',
                              ),
                              const Divider(),
                              _buildInfoRow(
                                'Keterangan', 
                                order.keterangan?.isNotEmpty == true ? order.keterangan! : '-',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Items
                    _buildSectionTitle('Item Pembelian'),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: order.items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = order.items[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.itemName),
                              subtitle: Text('${item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.cost)}'),
                              trailing: Text(
                                CurrencyFormatter.format(item.subtotal),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (item.batches.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Batches Diterima:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ...item.batches.map((batch) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.label_outline, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Batch: ${batch.batchNo}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(Icons.event_note, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Exp: ${DateFormatter.formatDate(batch.expiredDate)}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Qty: ${batch.quantity.toStringAsFixed(0)} ${item.unit}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                          ),
                                        ],
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Total
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppThemeColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppThemeColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Pembelian', style: AppTypography.titleMedium),
                          Text(
                            CurrencyFormatter.format(order.totalAmount),
                            style: AppTypography.headlineSmall.copyWith(
                              color: AppThemeColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons (only for pending + owner role)
            if (order.status == 'pending' && isOwner)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Pembelian?'),
                              content: const Text('Apakah Anda yakin ingin menghapus pembelian ini?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    context.read<PurchaseOrderCubit>().deletePurchaseOrder(order.id!);
                                  },
                                  child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final poCubit = context.read<PurchaseOrderCubit>();
                          final productCubit = context.read<ProductCubit>();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MultiBlocProvider(
                                providers: [
                                  BlocProvider.value(value: poCubit),
                                  BlocProvider.value(value: productCubit),
                                ],
                                child: ReceiveOrderScreen(order: order),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Terima Barang'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: AppTypography.titleSmall.copyWith(color: AppThemeColors.textSecondary),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'received':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
