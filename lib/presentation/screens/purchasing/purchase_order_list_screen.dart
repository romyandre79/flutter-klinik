import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/core/utils/currency_formatter.dart';
import 'package:kreatif_otopart/core/utils/date_formatter.dart';
import 'package:kreatif_otopart/logic/cubits/purchase_order/purchase_order_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/purchase_order/purchase_order_state.dart';
import 'package:kreatif_otopart/logic/cubits/supplier/supplier_cubit.dart';
import 'package:kreatif_otopart/presentation/screens/purchasing/purchase_order_create_screen.dart';
import 'package:kreatif_otopart/presentation/screens/purchasing/purchase_order_detail_screen.dart';
import 'package:kreatif_otopart/data/repositories/purchase_order_repository.dart';
import 'package:kreatif_otopart/logic/cubits/product/product_cubit.dart';
import 'package:kreatif_otopart/data/repositories/product_repository.dart';
import 'package:kreatif_otopart/logic/cubits/unit/unit_cubit.dart';
import 'package:kreatif_otopart/data/repositories/unit_repository.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PurchaseOrderCubit>().loadPurchaseOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: const Text('Pembelian'),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppThemeColors.primaryGradient,
          borderRadius: AppRadius.fullRadius,
          boxShadow: AppShadows.purple,
        ),
        child: FloatingActionButton.extended(
          heroTag: 'fab_purchase_order_list',
          onPressed: () {
            final poCubit = context.read<PurchaseOrderCubit>();
            final supplierCubit = context.read<SupplierCubit>();
            // ProductCubit is likely available in MainScreen context, or we create a new one.
            // Since ProductRepository is available, we can create a new ProductCubit
            // or pass the existing one if we can find it. 
            // MainScreen doesn't seem to expose ProductCubit globally (only inside tabs).
            // So we create a new one or use BlocProvider.value if we are in scope.
            // Dashboard has OrderCubit. Otopart has PosCubit. Settings has UserCubit.
            // ProductListScreen has ProductCubit.
            // So here we validly create a new one using the repository.
            final productRepo = context.read<ProductRepository>();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: poCubit),
                    BlocProvider.value(value: supplierCubit),
                    BlocProvider(
                      create: (_) => UnitCubit(UnitRepository())..loadUnits(),
                    ),
                  ],
                  child: const PurchaseOrderCreateScreen(),
                ),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'Pembelian Baru',
            style: AppTypography.labelMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: BlocBuilder<PurchaseOrderCubit, PurchaseOrderState>(
        builder: (context, state) {
          if (state is PoLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PoLoaded) {
            if (state.purchaseOrders.isEmpty) {
              return const Center(child: Text('Tidak ada data Pembelian'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: state.purchaseOrders.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final po = state.purchaseOrders[index];
                return Card(
                  child: ListTile(
                    onTap: () async {
                      // Fetch full PO with items
                      final repo = context.read<PurchaseOrderRepository>();
                      final fullPo = await repo.getPurchaseOrderById(po.id!);
                      if (fullPo != null && context.mounted) {
                        final poCubit = context.read<PurchaseOrderCubit>();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: poCubit,
                              child: PurchaseOrderDetailScreen(order: fullPo),
                            ),
                          ),
                        );
                      }
                    },
                    title: Text(po.supplier?.name ?? "Unknown"),
                    subtitle: Text('${DateFormatter.formatDate(po.orderDate)} - ${po.statusDisplay}'),
                    trailing: Text(
                      CurrencyFormatter.format(po.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            );
          }
          
          if (state is PoError) {
            return Center(child: Text(state.message));
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
