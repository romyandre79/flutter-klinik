import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/data/models/pengumuman_template.dart';
import 'package:kreatif_otopart/logic/cubits/pengumuman/pengumuman_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/pengumuman/pengumuman_state.dart';

class PengumumanTemplateScreen extends StatefulWidget {
  const PengumumanTemplateScreen({super.key});

  @override
  State<PengumumanTemplateScreen> createState() => _PengumumanTemplateScreenState();
}

class _PengumumanTemplateScreenState extends State<PengumumanTemplateScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PengumumanCubit>().loadTemplates();
  }

  void _showTemplateDialog({PengumumanTemplate? template}) {
    final titleController = TextEditingController(text: template?.title ?? '');
    final contentController = TextEditingController(text: template?.content ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Text(
          template == null ? 'Tambah Template' : 'Edit Template',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul Template',
                    hintText: 'Misal: Promo Layanan',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Judul tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'Isi Pesan',
                    hintText: 'Tulis pesan template di sini...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  validator: (v) => v?.isEmpty == true ? 'Isi tidak boleh kosong' : null,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gunakan [item_name] untuk nama produk otomatis.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newTemplate = PengumumanTemplate(
                  id: template?.id,
                  title: titleController.text.trim(),
                  content: contentController.text.trim(),
                  type: template?.type ?? 'general',
                );

                if (template == null) {
                  context.read<PengumumanCubit>().addTemplate(newTemplate);
                } else {
                  context.read<PengumumanCubit>().updateTemplate(newTemplate);
                }
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int id, String title) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Template?'),
        content: Text('Yakin ingin menghapus template "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              context.read<PengumumanCubit>().deleteTemplate(id);
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
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Master Template'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showTemplateDialog(),
            ),
          ],
        ),
        body: BlocBuilder<PengumumanCubit, PengumumanState>(
          builder: (context, state) {
            if (state is PengumumanLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is PengumumanLoaded) {
              final templates = state.templates;
              if (templates.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmarks_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Belum ada template', style: TextStyle(color: Colors.grey)),
                      ElevatedButton(
                        onPressed: () => _showTemplateDialog(),
                        child: const Text('Tambah Sekarang'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: templates.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final t = templates[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(t.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        t.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            onPressed: () => _showTemplateDialog(template: t),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmDelete(t.id!, t.title),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showTemplateDialog(),
          backgroundColor: AppThemeColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
