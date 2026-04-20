import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/core/utils/currency_formatter.dart';
import 'package:kreatif_klinik/data/models/product.dart';

class ProductItemCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductItemCard({
    super.key,
    required this.product,
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
              // Initial or Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppThemeColors.primarySurface,
                  borderRadius: AppRadius.smRadius,
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
                          style: AppTypography.titleMedium.copyWith(
                            color: AppThemeColors.primary,
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
                      '/${product.unit}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppThemeColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Price
              Text(
                CurrencyFormatter.format(product.price),
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
