import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/data/models/doctor.dart';
import 'package:kreatif_klinik/data/models/user.dart';
import 'package:kreatif_klinik/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_klinik/logic/cubits/doctor/doctor_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/doctor/doctor_state.dart';

class DoctorListScreen extends StatelessWidget {
  const DoctorListScreen({super.key});

  void _showDoctorDialog(BuildContext context, {Doctor? doctor}) {
    final isEditing = doctor != null;
    final nameController = TextEditingController(text: doctor?.name);
    final specController = TextEditingController(text: doctor?.specialization);
    final phoneController = TextEditingController(text: doctor?.phone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Text(
          isEditing ? 'Ubah Data Dokter' : 'Tambah Dokter Baru',
          style: AppTypography.titleLarge,
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nama Dokter',
                    hintText: 'Contoh: dr. Budi Santoso',
                    border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama dokter tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: specController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Spesialisasi',
                    hintText: 'Contoh: Umum, Anak, Kandungan',
                    border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Spesialisasi tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Nomor HP/Telp',
                    hintText: 'Contoh: 08123456789',
                    border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                  ),
                ),
              ],
            ),
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
                final name = nameController.text.trim();
                final specialization = specController.text.trim();
                final phone = phoneController.text.trim();
                final cubit = context.read<DoctorCubit>();

                if (isEditing) {
                  cubit.updateDoctor(doctor.copyWith(
                    name: name,
                    specialization: specialization,
                    phone: phone.isNotEmpty ? phone : null,
                  ));
                } else {
                  cubit.addDoctor(Doctor(
                    name: name,
                    specialization: specialization,
                    phone: phone.isNotEmpty ? phone : null,
                  ));
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

  void _confirmDelete(BuildContext context, Doctor doctor) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Text('Hapus Dokter?', style: AppTypography.titleLarge),
        content: Text(
          'Apakah Anda yakin ingin menghapus data dokter "${doctor.name}"?',
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
              context.read<DoctorCubit>().deleteDoctor(doctor.id!);
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
        title: const Text('Master Dokter', style: TextStyle(color: Colors.white)),
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
              onPressed: () => _showDoctorDialog(context),
              backgroundColor: AppThemeColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: BlocConsumer<DoctorCubit, DoctorState>(
        listener: (context, state) {
          if (state is DoctorError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppThemeColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is DoctorLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Doctor> doctors = [];
          if (state is DoctorLoaded) {
            doctors = state.doctors;
          }

          if (doctors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    size: 64,
                    color: AppThemeColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Belum ada data dokter',
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
            itemCount: doctors.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final doctor = doctors[index];
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
                      Icons.medical_services,
                      color: AppThemeColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    doctor.name,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Spesialisasi: ${doctor.specialization ?? "-"}\nTelp: ${doctor.phone ?? "-"}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppThemeColors.textSecondary,
                    ),
                  ),
                  isThreeLine: true,
                  trailing: isOwner
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppThemeColors.warning),
                              onPressed: () => _showDoctorDialog(context, doctor: doctor),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppThemeColors.error),
                              onPressed: () => _confirmDelete(context, doctor),
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
