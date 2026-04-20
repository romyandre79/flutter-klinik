import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/data/models/customer.dart';
import 'package:kreatif_klinik/data/models/pengumuman_template.dart';
import 'package:kreatif_klinik/data/repositories/customer_repository.dart';
import 'package:kreatif_klinik/core/services/fonnte_service.dart';
import 'package:kreatif_klinik/logic/cubits/pengumuman/pengumuman_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/pengumuman/pengumuman_state.dart';

class PengumumanScreen extends StatefulWidget {
  final String? productName;
  final String? initialTemplateType;

  const PengumumanScreen({
    super.key, 
    this.productName,
    this.initialTemplateType,
  });

  @override
  State<PengumumanScreen> createState() => _PengumumanScreenState();
}

class _PengumumanScreenState extends State<PengumumanScreen> {
  final CustomerRepository _customerRepository = CustomerRepository();
  final FonnteService _fonnteService = FonnteService();

  List<Customer> _customers = [];
  List<int> _selectedCustomerIds = [];
  PengumumanTemplate? _selectedTemplate;
  final _messageController = TextEditingController();
  bool _isLoadingCustomers = true;
  bool _isSending = false;
  String _targetType = 'all'; // 'all' or 'selected'

  @override
  void initState() {
    super.initState();
    context.read<PengumumanCubit>().loadTemplates();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final customers = await _customerRepository.getCustomers();
      setState(() {
        _customers = customers;
        _isLoadingCustomers = false;
      });
    } catch (e) {
      setState(() => _isLoadingCustomers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pelanggan: $e')),
        );
      }
    }
  }

  void _onTemplateSelected(PengumumanTemplate? template) {
    if (template != null) {
      setState(() {
        _selectedTemplate = template;
        // If we have a product name, replace the placeholder
        if (widget.productName != null) {
          _messageController.text = template.content.replaceAll('[item_name]', widget.productName!);
        } else {
          _messageController.text = template.content;
        }
      });
    }
  }

  Future<void> _sendBroadcast() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesan tidak boleh kosong')),
      );
      return;
    }

    List<Customer> targets = [];
    if (_targetType == 'all') {
      targets = _customers;
    } else {
      targets = _customers.where((c) => _selectedCustomerIds.contains(c.id)).toList();
    }

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 pelanggan')),
      );
      return;
    }

    setState(() => _isSending = true);
    int successCount = 0;

    try {
      final targetPhones = targets
          .where((c) => c.phone != null && c.phone!.isNotEmpty)
          .map((c) {
            String phone = c.phone!.replaceAll(RegExp(r'[^0-9]'), '');
            if (phone.startsWith('0')) phone = '62${phone.substring(1)}';
            return phone;
          })
          .join(',');

      if (targetPhones.isEmpty) {
        throw Exception('Tidak ada nomor HP valid untuk dikirim');
      }

      await _fonnteService.sendMessage(
        target: targetPhones,
        message: _messageController.text,
      );
      successCount = targets.length;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim: $e'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _isSending = false);
    if (successCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil mengirim ke $successCount pelanggan'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showSaveTemplateDialog() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tulis pesan terlebih dahulu')),
      );
      return;
    }

    final titleController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simpan Template'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Judul Template',
            hintText: 'Misal: Promo Akhir Bulan',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.trim().isNotEmpty) {
      final newTemplate = PengumumanTemplate(
        title: titleController.text.trim(),
        content: message,
        type: 'general',
      );
      context.read<PengumumanCubit>().addTemplate(newTemplate);
    }
  }

  Future<void> _showTemplatesModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return BlocBuilder<PengumumanCubit, PengumumanState>(
              builder: (context, state) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Kelola Template', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: state is PengumumanLoading
                          ? const Center(child: CircularProgressIndicator())
                          : state is PengumumanLoaded && state.templates.isNotEmpty
                              ? ListView.builder(
                                  controller: scrollController,
                                  itemCount: state.templates.length,
                                  itemBuilder: (context, index) {
                                    final t = state.templates[index];
                                    return ListTile(
                                      title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(t.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      onTap: () {
                                        _onTemplateSelected(t);
                                        Navigator.pop(context);
                                      },
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () {
                                          _confirmDeleteTemplate(t);
                                        },
                                      ),
                                    );
                                  },
                                )
                              : const Center(child: Text('Belum ada template')),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTemplate(PengumumanTemplate t) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Template?'),
        content: Text('Yakin ingin menghapus template "${t.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              context.read<PengumumanCubit>().deleteTemplate(t.id!);
              Navigator.pop(dialogContext);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PengumumanCubit, PengumumanState>(
      listener: (context, state) {
        if (state is PengumumanActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green),
          );
        } else if (state is PengumumanError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        } else if (state is PengumumanLoaded && widget.productName != null && _selectedTemplate == null) {
          // Auto-select template if productName is passed and no template selected yet
          final prefix = widget.initialTemplateType ?? '30';
          final template = state.templates.firstWhere(
            (t) => t.title.contains(prefix),
            orElse: () => state.templates.isNotEmpty ? state.templates.first : PengumumanTemplate(title: '', content: ''),
          );
          
          if (template.title.isNotEmpty) {
            _onTemplateSelected(template);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Broadcast Penjualan'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined),
              tooltip: 'Kelola Template',
              onPressed: _showTemplatesModal,
            ),
          ],
        ),
        body: _isLoadingCustomers
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('Pilih Template'),
                  const SizedBox(height: 8),
                  BlocBuilder<PengumumanCubit, PengumumanState>(
                    builder: (context, state) {
                      final templates = state is PengumumanLoaded ? state.templates : <PengumumanTemplate>[];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppThemeColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PengumumanTemplate>(
                            value: _selectedTemplate,
                            hint: const Text('Pilih template pengumuman'),
                            isExpanded: true,
                            items: templates.map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text(t.title),
                              );
                            }).toList(),
                            onChanged: _onTemplateSelected,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Isi Pesan'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan Anda di sini...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.save_outlined),
                            tooltip: 'Simpan sebagai Template',
                            onPressed: _showSaveTemplateDialog,
                            color: AppThemeColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Target Pelanggan'),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'all',
                        groupValue: _targetType,
                        onChanged: (v) => setState(() => _targetType = v!),
                      ),
                      const Text('Semua Pelanggan'),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'selected',
                        groupValue: _targetType,
                        onChanged: (v) => setState(() => _targetType = v!),
                      ),
                      const Text('Pilih Spesifik'),
                    ],
                  ),
                  if (_targetType == 'selected') _buildCustomerSelector(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendBroadcast,
                      icon: _isSending 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      label: Text(_isSending ? 'Mengirim...' : 'Kirim Sekarang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  Widget _buildCustomerSelector() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppThemeColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _customers.length,
          itemBuilder: (context, index) {
            final c = _customers[index];
            final isSelected = _selectedCustomerIds.contains(c.id);
            return CheckboxListTile(
              title: Text(c.name),
              subtitle: Text(c.phone ?? '-'),
              value: isSelected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedCustomerIds.add(c.id!);
                  } else {
                    _selectedCustomerIds.remove(c.id);
                  }
                });
              },
            );
          },
        ),
      ),
    );
  }
}
