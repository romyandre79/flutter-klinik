import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/core/theme/app_theme.dart';
import 'package:kreatif_pos/logic/cubits/pos/pos_cubit.dart';
import 'package:kreatif_pos/presentation/screens/pos/widgets/cart_panel.dart';
import 'package:kreatif_pos/presentation/screens/pos/widgets/service_catalog.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi Penjualan'),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppThemeColors.error),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Cart?'),
                  content: const Text('Are you sure you want to remove all items?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<PosCubit>().clearCart();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Clear', style: TextStyle(color: AppThemeColors.error)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left Side: Service Catalog (65%)
          const Expanded(
            flex: 65,
            child: ServiceCatalog(),
          ),
          
          // Right Side: Cart Panel (35%)
          Expanded(
            flex: 35,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                   left: BorderSide(color: AppThemeColors.border),
                ),
              ),
              child: const CartPanel(),
            ),
          ),
        ],
      ),
    );
  }
}
