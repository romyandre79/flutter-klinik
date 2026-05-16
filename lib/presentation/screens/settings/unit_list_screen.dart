import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/data/models/unit.dart';
import 'package:kreatif_klinik/data/models/user.dart';
import 'package:kreatif_klinik/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_klinik/logic/cubits/unit/unit_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/unit/unit_state.dart';

class UnitListScreen extends StatelessWidget {
  const UnitListScreen({super.key});

  void _showUnitDialog(BuildContext context, {Unit? unit}) {
    final isEditing = unit != null;
    final controller = TextEditingController(text: unit?.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Text(
          isEditing ? 'Ubah Satuan' : 'Tambah Satuan',
          style: AppTypography.titleLarge,
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nama Satuan',
              hintText: 'Contoh: pcs, kg, pack',
              border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama satuan tidak boleh kosong';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Batal',
              style: AppTypography.labelMedium.copyWith(
                color: AppThemeColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final name = controller.text.trim();
                if (isEditing) {
                  context.read<UnitCubit>().updateUnit(unit.copyWith(name: name));
                } else {
                  context.read<UnitCubit>().addUnit(name);
                }
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.primary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
            ),
            child: Text(
              'Simpan',
              style: AppTypography.labelMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Unit unit) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Text('Hapus Satuan?', style: AppTypography.titleLarge),
        content: Text(
          'Apakah Anda yakin ingin menghapus satuan "${unit.name}"?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Batal',
              style: AppTypography.labelMedium.copyWith(
                color: AppThemeColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<UnitCubit>().deleteUnit(unit.id!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.error,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
            ),
            child: Text(
              'Hapus',
              style: AppTypography.labelMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthCubit>().state as AuthAuthenticated).user;
    final isOwner = user.role == UserRole.owner;

    return Scaffold(
      backgroundColor: AppThemeColors.background,
      appBar: AppBar(
        title: const Text('Master Satuan', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppThemeColors.headerGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton(
              onPressed: () => _showUnitDialog(context),
              backgroundColor: AppThemeColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: BlocConsumer<UnitCubit, UnitState>(
        listener: (context, state) {
          if (state is UnitOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppThemeColors.success,
              ),
            );
          } else if (state is UnitError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppThemeColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is UnitLoading && state is! UnitOperationSuccess) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Unit> units = [];
          
          if (state is UnitLoaded) {
            units = state.units;
          } else if (state is UnitOperationSuccess) {
            units = state.units;
          }

          if (units.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.straighten,
                    size: 64,
                    color: AppThemeColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Belum ada data satuan',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppThemeColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: units.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final unit = units[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.mdRadius,
                  boxShadow: AppShadows.small,
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppThemeColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.smRadius,
                    ),
                    child: const Icon(
                      Icons.straighten, // Changed icon
                      color: AppThemeColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    unit.name,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: isOwner
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppThemeColors.warning),
                              onPressed: () => _showUnitDialog(context, unit: unit),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppThemeColors.error),
                              onPressed: () => _confirmDelete(context, unit),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
