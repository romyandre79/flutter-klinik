import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/logic/cubits/pos/pos_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/pos/pos_state.dart';
import 'package:kreatif_otopart/presentation/screens/pos/widgets/product_item_card.dart';
import 'package:kreatif_otopart/data/models/product.dart';
import 'package:kreatif_otopart/data/models/product_unit.dart';

class ServiceCatalog extends StatelessWidget {
  const ServiceCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter & Search Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          color: Colors.white,
          child: Column(
            children: [
              // Search Field
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Cari Barang/Jasa...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
                onChanged: (query) {
                  context.read<PosCubit>().filterProducts(query: query);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              // Category Tabs
              BlocBuilder<PosCubit, PosState>(
                builder: (context, state) {
                  final cubit = context.read<PosCubit>();
                  final categories = ['All', ...cubit.availableCategories];
                  
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((category) {
                        final isSelected = state is PosLoaded && state.selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(category.toUpperCase()),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                cubit.filterProducts(category: category);
                              }
                            },
                            selectedColor: AppThemeColors.primarySurface,
                            labelStyle: TextStyle(
                              color: isSelected ? AppThemeColors.primary : AppThemeColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Grid
        Expanded(
          child: BlocBuilder<PosCubit, PosState>(
            builder: (context, state) {
              if (state is PosLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is PosLoaded) {
                if (state.filteredProducts.isEmpty) {
                   return const Center(child: Text('Master Item Belum Terisi'));
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double itemWidth = 140; 
                    final int crossAxisCount = (constraints.maxWidth / itemWidth).floor().clamp(2, 6); // Min 2, Max 6 cols

                final flattenedItems = _getFlattenedItems(state.filteredProducts);

                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount, 
                    childAspectRatio: 0.8, 
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                  ),
                  itemCount: flattenedItems.length,
                  itemBuilder: (context, index) {
                    final item = flattenedItems[index];
                    return ProductItemCard(
                      product: item.product,
                      selectedUnit: item.unit,
                      onTap: () {
                        context.read<PosCubit>().addToCart(item.product, unit: item.unit);
                      },
                    );
                  },
                );
                final flattenedItems = _getFlattenedItems(state.filteredProducts);

                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount, 
                    childAspectRatio: 0.8, 
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                  ),
                  itemCount: flattenedItems.length,
                  itemBuilder: (context, index) {
                    final item = flattenedItems[index];
                    return ProductItemCard(
                      product: item.product,
                      selectedUnit: item.unit,
                      onTap: () {
                        context.read<PosCubit>().addToCart(item.product, unit: item.unit);
                      },
                    );
                  },
                );
                  }
                );
              }

              return const Center(child: Text('Something went wrong'));
            },
          ),
        ),
      ],
    );
  }

  /// Helper to flatten products into an item list for the grid.
  /// Each item is a record containing the product and an optional specific unit.
  List<({Product product, ProductUnit? unit})> _getFlattenedItems(List<Product> products) {
    final List<({Product product, ProductUnit? unit})> items = [];
    
    for (var product in products) {
      if (product.type == ProductType.goods && product.units.isNotEmpty) {
        // Add a card for each unit
        for (var unit in product.units) {
          items.add((product: product, unit: unit));
        }
      } else {
        // Add a single card for service or product without specified units
        items.add((product: product, unit: null));
      }
    }
    
    return items;
  }
  /// Helper to flatten products into an item list for the grid.
  /// Each item is a record containing the product and an optional specific unit.
  List<({Product product, ProductUnit? unit})> _getFlattenedItems(List<Product> products) {
    final List<({Product product, ProductUnit? unit})> items = [];
    
    for (var product in products) {
      if (product.type == ProductType.goods && product.units.isNotEmpty) {
        // Add a card for each unit
        for (var unit in product.units) {
          items.add((product: product, unit: unit));
        }
      } else {
        // Add a single card for service or product without specified units
        items.add((product: product, unit: null));
      }
    }
    
    return items;
  }
}
