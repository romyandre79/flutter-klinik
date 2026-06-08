import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/core/utils/date_formatter.dart';
import 'package:kreatif_klinik/data/models/registration.dart';
import 'package:kreatif_klinik/logic/cubits/registration/registration_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/registration/registration_state.dart';
import 'package:kreatif_klinik/presentation/screens/registration/registration_form_screen.dart';
import 'package:kreatif_klinik/presentation/screens/examination/examination_form_screen.dart';
import 'package:kreatif_klinik/data/repositories/examination_repository.dart';
import 'package:kreatif_klinik/data/repositories/registration_repository.dart';
import 'package:kreatif_klinik/logic/cubits/examination/examination_cubit.dart';

class RegistrationListScreen extends StatefulWidget {
  final bool filterActive;

  const RegistrationListScreen({super.key, this.filterActive = false});

  @override
  State<RegistrationListScreen> createState() => _RegistrationListScreenState();
}

class _RegistrationListScreenState extends State<RegistrationListScreen> {
  late bool _showOnlyActive;

  @override
  void initState() {
    super.initState();
    _showOnlyActive = widget.filterActive;
    context.read<RegistrationCubit>().loadRegistrations();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppThemeColors.warning;
      case 'examining':
        return AppThemeColors.primary;
      case 'completed':
        return AppThemeColors.success;
      case 'cancelled':
        return AppThemeColors.error;
      default:
        return AppThemeColors.textSecondary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Antri / Pending';
      case 'examining':
        return 'Memeriksa';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Batal';
      default:
        return status;
    }
  }

  void _showDetailMedis(BuildContext context, Registration reg) async {
    final examRepo = context.read<ExaminationRepository>();
    final exam = await examRepo.getExaminationByRegistrationId(reg.id!);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Row(
          children: [
            const Icon(Icons.description, color: AppThemeColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detail Pemeriksaan',
                style: AppTypography.titleLarge,
              ),
            ),
          ],
        ),
        content: exam == null
            ? const Text('Belum ada rekam medis untuk pendaftaran ini.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Pasien', reg.customerName ?? '-'),
                  _buildDetailRow('Dokter', reg.doctorName ?? '-'),
                  _buildDetailRow('No. Reg', reg.registrationNo),
                  const Divider(),
                  _buildDetailRow('Gejala / Keluhan', exam.symptoms ?? '-'),
                  _buildDetailRow('Diagnosis', exam.diagnosis ?? '-'),
                  _buildDetailRow('Terapi / Tindakan', exam.therapy ?? '-'),
                  _buildDetailRow('Catatan / Resep', exam.notes ?? '-'),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppThemeColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, Registration reg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: const Text('Batalkan Pendaftaran?'),
        content: Text('Apakah Anda yakin ingin membatalkan pendaftaran ${reg.registrationNo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: TextStyle(color: AppThemeColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppThemeColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RegistrationCubit>().updateStatus(reg.id!, 'cancelled');
            },
            child: const Text('Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      appBar: AppBar(
        title: Text(
          _showOnlyActive ? 'Pemeriksaan Pasien' : 'Pendaftaran Pasien',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppThemeColors.headerGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Filter toggle
          IconButton(
            icon: Icon(
              _showOnlyActive ? Icons.filter_list_alt : Icons.filter_list,
              color: Colors.white,
            ),
            tooltip: _showOnlyActive ? 'Tampilkan Semua' : 'Tampilkan Antrean Aktif',
            onPressed: () {
              setState(() {
                _showOnlyActive = !_showOnlyActive;
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RegistrationFormScreen(),
            ),
          );
        },
        backgroundColor: AppThemeColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: BlocConsumer<RegistrationCubit, RegistrationState>(
        listener: (context, state) {
          if (state is RegistrationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppThemeColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is RegistrationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Registration> list = [];
          if (state is RegistrationLoaded) {
            list = state.registrations;
          }

          // Apply active filter if toggled
          if (_showOnlyActive) {
            list = list.where((r) => r.status == 'pending' || r.status == 'examining').toList();
          }

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showOnlyActive ? Icons.healing_outlined : Icons.assignment_ind_outlined,
                    size: 64,
                    color: AppThemeColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _showOnlyActive ? 'Tidak ada antrean pasien aktif' : 'Belum ada data pendaftaran',
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
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final reg = list[index];
              final statusColor = _getStatusColor(reg.status);
              final statusLabel = _getStatusLabel(reg.status);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.mdRadius,
                  boxShadow: AppShadows.small,
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: No Reg & Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          reg.registrationNo,
                          style: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: AppRadius.fullRadius,
                          ),
                          child: Text(
                            statusLabel,
                            style: AppTypography.labelSmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    
                    // Patient & Doctor Info
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppThemeColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Pasien: ',
                          style: AppTypography.bodySmall.copyWith(color: AppThemeColors.textSecondary),
                        ),
                        Text(
                          reg.customerName ?? '-',
                          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.medical_services_outlined, size: 16, color: AppThemeColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Dokter: ',
                          style: AppTypography.bodySmall.copyWith(color: AppThemeColors.textSecondary),
                        ),
                        Text(
                          reg.doctorName ?? '-',
                          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppThemeColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Tanggal: ',
                          style: AppTypography.bodySmall.copyWith(color: AppThemeColors.textSecondary),
                        ),
                        Text(
                          DateFormatter.formatDateTime(reg.registrationDate),
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),

                    if (reg.complaint != null && reg.complaint!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppThemeColors.background,
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: Text(
                          'Keluhan: ${reg.complaint}',
                          style: AppTypography.bodySmall.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),

                    // Actions Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (reg.status == 'pending') ...[
                          TextButton.icon(
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text('Mulai Periksa'),
                            style: TextButton.styleFrom(foregroundColor: AppThemeColors.primary),
                            onPressed: () {
                              context.read<RegistrationCubit>().updateStatus(reg.id!, 'examining');
                            },
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          TextButton.icon(
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Batalkan'),
                            style: TextButton.styleFrom(foregroundColor: AppThemeColors.error),
                            onPressed: () => _confirmCancel(context, reg),
                          ),
                        ],
                        if (reg.status == 'examining') ...[
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit_note, size: 16, color: Colors.white),
                            label: const Text('Catat Hasil Periksa', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider(
                                    create: (context) => ExaminationCubit(
                                      examinationRepository: context.read<ExaminationRepository>(),
                                      registrationRepository: context.read<RegistrationRepository>(),
                                    ),
                                    child: ExaminationFormScreen(registration: reg),
                                  ),
                                ),
                              ).then((_) {
                                if (context.mounted) {
                                  context.read<RegistrationCubit>().loadRegistrations();
                                }
                              });
                            },
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          TextButton.icon(
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Batalkan'),
                            style: TextButton.styleFrom(foregroundColor: AppThemeColors.error),
                            onPressed: () => _confirmCancel(context, reg),
                          ),
                        ],
                        if (reg.status == 'completed') ...[
                          OutlinedButton.icon(
                            icon: const Icon(Icons.visibility, size: 16, color: AppThemeColors.success),
                            label: const Text('Detail Rekam Medis', style: TextStyle(color: AppThemeColors.success)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppThemeColors.success),
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                            ),
                            onPressed: () => _showDetailMedis(context, reg),
                          ),
                        ],
                        if (reg.status == 'cancelled') ...[
                          Text(
                            'Pendaftaran dibatalkan',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppThemeColors.error,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
