import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kreatif_pos/core/theme/app_theme.dart';
import 'package:kreatif_pos/core/utils/currency_formatter.dart';
import 'package:kreatif_pos/data/models/product.dart';
import 'package:kreatif_pos/data/models/product_unit.dart';

class ProductItemCard extends StatelessWidget {
  final Product product;
  final ProductUnit? selectedUnit;
  final VoidCallback onTap;

  const ProductItemCard({
    super.key,
    required this.product,
    this.selectedUnit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdRadius,
        side: BorderSide(color: AppThemeColors.border.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Product Image / Placeholder
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: AppThemeColors.primarySurface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  image: product.imageUrl != null && File(product.imageUrl!).existsSync()
                      ? DecorationImage(
                          image: FileImage(File(product.imageUrl!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.imageUrl != null && File(product.imageUrl!).existsSync()
                    ? null
                    : Center(
                        child: Text(
                          product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
                          style: AppTypography.titleLarge.copyWith(
                            color: AppThemeColors.primary.withValues(alpha: 0.5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Name and Unit
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '/${selectedUnit?.unitName ?? product.unit}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppThemeColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Stock Indicator
              if (product.type == ProductType.goods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (selectedUnit?.stock ?? product.stock ?? 0) > 0 
                        ? Colors.green.withValues(alpha: 0.1) 
                        : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Stok: ${selectedUnit?.stock ?? product.stock ?? 0}',
                      style: AppTypography.labelSmall.copyWith(
                        color: (selectedUnit?.stock ?? product.stock ?? 0) > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              // Price
              Text(
                CurrencyFormatter.format(selectedUnit?.price ?? product.price),
                style: AppTypography.titleMedium.copyWith(
                  color: AppThemeColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
