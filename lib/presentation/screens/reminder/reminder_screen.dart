import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/data/models/product.dart';
import 'package:kreatif_klinik/data/repositories/product_repository.dart';
import 'package:intl/intl.dart';
import 'package:kreatif_klinik/presentation/screens/pengumuman/pengumuman_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/logic/cubits/pengumuman/pengumuman_cubit.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final ProductRepository _productRepository = ProductRepository();
  bool _isLoading = true;
  List<Product> _expiredItems = [];
  List<Product> _criticalItems = [];
  List<Product> _warningItems = [];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productRepository.getProducts(activeOnly: true);
      final now = DateTime.now();

      final List<Product> expired = [];
      final List<Product> critical = [];
      final List<Product> warning = [];

      for (final p in products) {
        if (p.expireDays > 0 && p.createdAt != null) {
          final expireDate = p.createdAt!.add(Duration(days: p.expireDays));
          final difference = expireDate.difference(now).inDays;

          if (difference < 0) {
            expired.add(p);
          } else if (difference <= 15) {
            critical.add(p);
          } else if (difference <= 30) {
            warning.add(p);
          }
        }
      }

      setState(() {
        _expiredItems = expired;
        _criticalItems = critical;
        _warningItems = warning;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pengingat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengingat Kedaluwarsa'),
        actions: [
          IconButton(
            onPressed: _loadReminders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReminders,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                   _buildSection(
                    title: 'Sangat Mendesak (Selesai)',
                    items: _expiredItems,
                    color: Colors.red,
                    icon: Icons.error_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Mendesak (<= 15 Hari)',
                    items: _criticalItems,
                    color: Colors.orange,
                    icon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Peringatan (<= 30 Hari)',
                    items: _warningItems,
                    color: Colors.blue,
                    icon: Icons.info_outline,
                  ),
                  if (_expiredItems.isEmpty && _criticalItems.isEmpty && _warningItems.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 64),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline, 
                              size: 64, color: Colors.green.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(
                              'Semua stok aman!',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: AppThemeColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Product> items,
    required Color color,
    required IconData icon,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            const Spacer(),
            Text(
              '${items.length} Item',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppThemeColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((p) => _buildItemCard(p, color)),
      ],
    );
  }

  Widget _buildItemCard(Product p, Color color) {
    final expireDate = p.createdAt!.add(Duration(days: p.expireDays));
    final dateStr = DateFormat('dd MMM yyyy').format(expireDate);
    final daysLeft = expireDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        title: Text(
          p.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exp: $dateStr'),
            Text(
              daysLeft < 0 
                ? 'Sudah lewat ${daysLeft.abs()} hari' 
                : 'Sisa $daysLeft hari lagi',
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Stok: ${p.stock ?? 0} ${p.unit}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.send, color: color),
              tooltip: 'Notify Customer',
              onPressed: () {
                final expireDate = p.createdAt!.add(Duration(days: p.expireDays));
                final daysLeft = expireDate.difference(DateTime.now()).inDays;
                String templateType = '30';
                if (daysLeft <= 15) templateType = '15';

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PengumumanScreen(
                          productName: p.name,
                          initialTemplateType: templateType,
                        ),
                      ),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}
