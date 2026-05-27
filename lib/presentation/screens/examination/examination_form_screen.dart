import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/data/models/examination.dart';
import 'package:kreatif_klinik/data/models/registration.dart';
import 'package:kreatif_klinik/logic/cubits/examination/examination_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/examination/examination_state.dart';

class ExaminationFormScreen extends StatefulWidget {
  final Registration registration;

  const ExaminationFormScreen({super.key, required this.registration});

  @override
  State<ExaminationFormScreen> createState() => _ExaminationFormScreenState();
}

class _ExaminationFormScreenState extends State<ExaminationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _symptomsController;
  final _diagnosisController = TextEditingController();
  final _therapyController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default symptoms with the complaint
    _symptomsController = TextEditingController(text: widget.registration.complaint);
    context.read<ExaminationCubit>().loadExamination(widget.registration.id!);
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    _diagnosisController.dispose();
    _therapyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveExamination() {
    if (_formKey.currentState!.validate()) {
      final exam = Examination(
        registrationId: widget.registration.id!,
        symptoms: _symptomsController.text.trim(),
        diagnosis: _diagnosisController.text.trim(),
        therapy: _therapyController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      context.read<ExaminationCubit>().saveExamination(exam);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      appBar: AppBar(
        title: const Text('Catat Hasil Pemeriksaan', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppThemeColors.headerGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocConsumer<ExaminationCubit, ExaminationState>(
        listener: (context, state) {
          if (state is ExaminationSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Hasil pemeriksaan berhasil disimpan!'),
                backgroundColor: AppThemeColors.success,
              ),
            );
            Navigator.pop(context);
          } else if (state is ExaminationLoaded && state.examination != null) {
            final exam = state.examination!;
            _symptomsController.text = exam.symptoms ?? '';
            _diagnosisController.text = exam.diagnosis ?? '';
            _therapyController.text = exam.therapy ?? '';
            _notesController.text = exam.notes ?? '';
          } else if (state is ExaminationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppThemeColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ExaminationLoading && state is! ExaminationSaved) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Registration Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.mdRadius,
                      boxShadow: AppShadows.small,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.registration.registrationNo,
                              style: AppTypography.labelMedium.copyWith(
                                color: AppThemeColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Pemeriksaan',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppThemeColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.registration.customerName ?? '-',
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pemeriksa: ${widget.registration.doctorName ?? "-"}',
                          style: AppTypography.bodySmall.copyWith(color: AppThemeColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Form Fields
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.lgRadius,
                      boxShadow: AppShadows.medium,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Symptoms
                        Text(
                          'Gejala / Keluhan Fisik',
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _symptomsController,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Masukkan gejala fisik pasien...',
                            border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Gejala tidak boleh kosong'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Diagnosis
                        Text(
                          'Diagnosis Medis',
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _diagnosisController,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Contoh: Influenza, Gastritis akut...',
                            border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Diagnosis tidak boleh kosong'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Therapy
                        Text(
                          'Terapi / Tindakan / Obat',
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _therapyController,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Tindakan medis yang diberikan atau obat...',
                            border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Terapi/Tindakan tidak boleh kosong'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Notes
                        Text(
                          'Catatan Tambahan / Resep',
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Catatan resep obat atau rujukan...',
                            border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                          ),
                        ),
                        
                        const SizedBox(height: AppSpacing.xl),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                            ),
                            onPressed: _saveExamination,
                            child: Text(
                              'Simpan Hasil Periksa',
                              style: AppTypography.labelLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
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
        },
      ),
    );
  }
}
