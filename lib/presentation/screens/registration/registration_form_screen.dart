import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/data/models/customer.dart';
import 'package:kreatif_klinik/data/models/doctor.dart';
import 'package:kreatif_klinik/data/models/registration.dart';
import 'package:kreatif_klinik/logic/cubits/customer/customer_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/customer/customer_state.dart';
import 'package:kreatif_klinik/logic/cubits/doctor/doctor_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/doctor/doctor_state.dart';
import 'package:kreatif_klinik/logic/cubits/registration/registration_cubit.dart';

class RegistrationFormScreen extends StatefulWidget {
  const RegistrationFormScreen({super.key});

  @override
  State<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _registrationNo = 'REG-Loading...';
  Customer? _selectedPatient;
  Doctor? _selectedDoctor;
  final _complaintController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRegistrationNo();
    context.read<DoctorCubit>().loadDoctors();
    context.read<CustomerCubit>().loadCustomers();
  }

  void _loadRegistrationNo() async {
    final regNo = await context.read<RegistrationCubit>().getNextRegistrationNo();
    setState(() {
      _registrationNo = regNo;
    });
  }

  void _showAddPatientDialog() {
    final patientFormKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: const Text('Tambah Pasien Baru'),
        content: SingleChildScrollView(
          child: Form(
            key: patientFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap Pasien',
                    border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nama pasien tidak boleh kosong'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Nomor HP',
                    border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: addressController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Alamat',
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
            child: Text('Batal', style: TextStyle(color: AppThemeColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (patientFormKey.currentState!.validate()) {
                final customerCubit = context.read<CustomerCubit>();
                
                final newCustomer = Customer(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                  address: addressController.text.trim().isNotEmpty ? addressController.text.trim() : null,
                );

                await customerCubit.createCustomer(newCustomer);
                
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                
                // Set the newly created customer as selected
                // We reload customers and wait briefly for state to update
                await Future.delayed(const Duration(milliseconds: 300));
                if (!mounted) return;
                
                final updatedState = customerCubit.state;
                if (updatedState is CustomerLoaded) {
                  final created = updatedState.customers.firstWhere(
                    (c) => c.name == newCustomer.name && c.phone == newCustomer.phone,
                    orElse: () => updatedState.customers.first,
                  );
                  setState(() {
                    _selectedPatient = created;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.primary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
            ),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPatientPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (stContext, setSheetState) {
            final customerCubit = context.read<CustomerCubit>();
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                top: AppSpacing.lg,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: MediaQuery.of(stContext).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pilih Pasien', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Search and add row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Cari nama atau nomor HP...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                          ),
                          onChanged: (query) {
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showAddPatientDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeColors.primarySurface,
                          foregroundColor: AppThemeColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add, size: 18),
                            SizedBox(width: 4),
                            Text('Baru'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  Expanded(
                    child: BlocBuilder<CustomerCubit, CustomerState>(
                      bloc: customerCubit,
                      builder: (context, state) {
                        if (state is CustomerLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        List<Customer> list = [];
                        if (state is CustomerLoaded) {
                          list = state.customers;
                        }

                        if (list.isEmpty) {
                          return const Center(child: Text('Belum ada data pasien'));
                        }

                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final patient = list[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppThemeColors.primary.withValues(alpha: 0.1),
                                child: const Icon(Icons.person, color: AppThemeColors.primary),
                              ),
                              title: Text(patient.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(patient.phone ?? 'No HP: -'),
                              onTap: () {
                                setState(() {
                                  _selectedPatient = patient;
                                });
                                Navigator.pop(sheetContext);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _saveRegistration() {
    if (_formKey.currentState!.validate()) {
      if (_selectedPatient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan pilih pasien terlebih dahulu'),
            backgroundColor: AppThemeColors.error,
          ),
        );
        return;
      }
      if (_selectedDoctor == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan pilih dokter terlebih dahulu'),
            backgroundColor: AppThemeColors.error,
          ),
        );
        return;
      }

      final reg = Registration(
        registrationNo: _registrationNo,
        customerId: _selectedPatient!.id!,
        doctorId: _selectedDoctor!.id!,
        registrationDate: DateTime.now(),
        complaint: _complaintController.text.trim(),
        status: 'pending',
      );

      context.read<RegistrationCubit>().addRegistration(reg);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      appBar: AppBar(
        title: const Text('Pendaftaran Pasien Baru', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppThemeColors.headerGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
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
                    Text(
                      'NOMOR PENDAFTARAN',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppThemeColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _registrationNo,
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppThemeColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Form fields Card
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
                    // Patient Selection
                    Text(
                      'Pilih Pasien',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    InkWell(
                      onTap: _showPatientPicker,
                      borderRadius: AppRadius.mdRadius,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppThemeColors.border),
                          borderRadius: AppRadius.mdRadius,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _selectedPatient == null
                                  ? Text(
                                      'Ketuk untuk memilih / tambah pasien...',
                                      style: TextStyle(color: AppThemeColors.textSecondary),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedPatient!.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text('Telp: ${_selectedPatient!.phone ?? "-"}'),
                                      ],
                                    ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: AppThemeColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Doctor Selection
                    Text(
                      'Pilih Dokter',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    BlocBuilder<DoctorCubit, DoctorState>(
                      builder: (context, state) {
                        List<Doctor> doctors = [];
                        if (state is DoctorLoaded) {
                          doctors = state.doctors;
                        }

                        return DropdownButtonFormField<Doctor>(
                          initialValue: _selectedDoctor,
                          hint: const Text('Pilih dokter pemeriksa...'),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                          ),
                          items: doctors.map((doc) {
                            return DropdownMenuItem<Doctor>(
                              value: doc,
                              child: Text('${doc.name} (${doc.specialization ?? "-"})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedDoctor = val;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Silakan pilih dokter pemeriksa' : null,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Complaint
                    Text(
                      'Keluhan Utama',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _complaintController,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Tuliskan gejala atau keluhan pasien...',
                        border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Keluhan tidak boleh kosong'
                          : null,
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                        ),
                        onPressed: _saveRegistration,
                        child: Text(
                          'Daftarkan Pasien',
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
      ),
    );
  }
}
