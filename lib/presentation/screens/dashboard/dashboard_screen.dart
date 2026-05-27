import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/core/utils/currency_formatter.dart';
import 'package:kreatif_otopart/core/utils/date_formatter.dart';
import 'package:kreatif_otopart/data/models/order.dart';
import 'package:kreatif_otopart/data/models/user.dart';
import 'package:kreatif_otopart/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_otopart/logic/cubits/dashboard/dashboard_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/dashboard/dashboard_state.dart';
import 'package:kreatif_otopart/logic/cubits/order/order_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/printer/printer_cubit.dart';
import 'package:kreatif_otopart/presentation/screens/orders/order_detail_screen.dart';
import 'package:kreatif_otopart/presentation/screens/orders/order_list_screen.dart';
import 'package:kreatif_otopart/presentation/screens/settings/printer_settings_screen.dart';
import 'package:kreatif_otopart/presentation/widgets/order_card.dart';
import 'package:kreatif_otopart/data/repositories/product_repository.dart';
import 'package:kreatif_otopart/logic/cubits/pos/pos_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/purchase_order/purchase_order_cubit.dart';
import 'package:kreatif_otopart/presentation/screens/purchasing/purchase_order_list_screen.dart';
import 'package:kreatif_otopart/data/repositories/purchase_order_repository.dart';
import 'package:kreatif_otopart/logic/cubits/supplier/supplier_cubit.dart';
import 'package:kreatif_otopart/data/repositories/supplier_repository.dart';
import 'package:kreatif_otopart/presentation/screens/pos/pos_screen.dart';
import 'package:kreatif_otopart/presentation/screens/pengumuman/pengumuman_screen.dart';
import 'package:kreatif_otopart/presentation/screens/reminder/reminder_screen.dart';
import 'package:kreatif_otopart/presentation/screens/inventory/stock_transfer_screen.dart';
import 'package:kreatif_otopart/presentation/screens/inventory/unit_conversion_screen.dart';
import 'package:kreatif_otopart/logic/cubits/pengumuman/pengumuman_cubit.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int index)? onSwitchTab;

  const DashboardScreen({
    super.key,
    this.onSwitchTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}


class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // DashboardCubit is now provided by parent
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.kasir:
        return 'Kasir';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;

        return Scaffold(
          backgroundColor: AppThemeColors.background,
          body: BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<DashboardCubit>().loadDashboard();
                },
                color: AppThemeColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with gradient
                      _buildHeader(user, state),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quick Actions
                            _buildQuickActions(),

                            const SizedBox(height: AppSpacing.xl),

                            // Order Status Section
                            _buildOrderStatusSection(state),

                            const SizedBox(height: AppSpacing.xl),

                            // Recent Orders
                            _buildRecentOrders(state),

                            const SizedBox(height: AppSpacing.lg),
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
      },
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppThemeColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.logout,
                color: AppThemeColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari aplikasi?',
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
              context.read<AuthCubit>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Logout',
              style: AppTypography.labelMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(User? user, DashboardState state) {
    int todayRevenue = 0;
    int monthOrders = 0;

    if (state is DashboardLoaded) {
      todayRevenue = state.todayRevenue;
      monthOrders = state.monthOrderCount;
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppThemeColors.headerGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              // Top row - User info
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.fullRadius,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppThemeColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Name & greeting
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat Datang,',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          user?.name ?? 'User',
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: AppRadius.fullRadius,
                    ),
                    child: Text(
                      user != null ? _getRoleDisplayName(user.role) : '-',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Logout button
                  GestureDetector(
                    onTap: _showLogoutConfirmation,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: AppRadius.fullRadius,
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _buildHeaderStatCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Omzet Hari Ini',
                      value: CurrencyFormatter.formatCompact(todayRevenue),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _buildHeaderStatCard(
                      icon: Icons.receipt_long_outlined,
                      label: 'Penjualan Bulan Ini',
                      value: monthOrders.toString(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Menu Cepat',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionItem(
                icon: MediaQuery.of(context).size.width > 800 ? Icons.point_of_sale : Icons.receipt_long,
                label: MediaQuery.of(context).size.width > 800 ? 'Kasir' : 'Penjualan',
                color: AppThemeColors.primary,
                onTap: () {
                  if (widget.onSwitchTab != null) {
                    widget.onSwitchTab!(1); // Index 1 is usually Sales/Kasir
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider(
                          create: (context) => PosCubit(
                            context.read<ProductRepository>(),
                          )..loadProducts(),
                          child: PosScreen(),
                        ),
                      ),
                    ).then((_) {
                      if (context.mounted) {
                        context.read<DashboardCubit>().loadDashboard();
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.shopping_bag,
                label: 'Pembelian',
                color: AppThemeColors.primary,
                onTap: () {
                  if (widget.onSwitchTab != null) {
                    widget.onSwitchTab!(2); // Index 2 is usually Purchasing
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MultiBlocProvider(
                          providers: [
                            BlocProvider(
                              create: (context) => PurchaseOrderCubit(
                                repository: context.read<PurchaseOrderRepository>(),
                              ),
                            ),
                            BlocProvider(
                              create: (context) => SupplierCubit(
                                supplierRepository: context.read<SupplierRepository>(),
                              ),
                            ),
                          ],
                          child: const PurchaseOrderListScreen(),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.print,
                label: 'Printer',
                color: AppThemeColors.warning,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => PrinterCubit(),
                        child: const PrinterSettingsScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.campaign,
                label: 'Broadcast',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PengumumanScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.notification_important,
                label: 'Pengingat',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReminderScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.swap_horiz,
                label: 'Transfer',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StockTransferScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.unfold_more,
                label: 'Konversi',
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UnitConversionScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.assignment_ind,
                label: 'Pendaftaran',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistrationListScreen(filterActive: false),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.fact_check,
                label: 'Pemeriksaan',
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistrationListScreen(filterActive: true),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgRadius,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.mdRadius,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusSection(DashboardState state) {
    Map<OrderStatus, int> counts = {
      OrderStatus.pending: 0,
      OrderStatus.process: 0,
      OrderStatus.ready: 0,
      OrderStatus.done: 0,
    };

    if (state is DashboardLoaded) {
      counts = Map.from(state.todayStatusCounts);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Hari Ini (${DateFormatter.formatDate(DateTime.now())})',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _buildStatusItem(
              'Pending',
              counts[OrderStatus.pending] ?? 0,
              AppThemeColors.warning,
            ),
            _buildStatusDivider(),
            _buildStatusItem(
              'Proses',
              counts[OrderStatus.process] ?? 0,
              AppThemeColors.primary,
            ),
            _buildStatusDivider(),
            _buildStatusItem(
              'Siap',
              counts[OrderStatus.ready] ?? 0,
              AppThemeColors.success,
            ),
            _buildStatusDivider(),
            _buildStatusItem(
              'Selesai',
              counts[OrderStatus.done] ?? 0,
              AppThemeColors.completed,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                count.toString(),
                style: AppTypography.titleMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppThemeColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDivider() {
    return Container(
      width: 1,
      height: 50,
      color: AppThemeColors.border,
    );
  }

  Widget _buildRecentOrders(DashboardState state) {
    List<Order> recentOrders = [];

    if (state is DashboardLoaded) {
      // Limit to 5 orders
      recentOrders = state.recentOrders.take(5).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Penjualan Terbaru',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                // Navigate to orders list
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<OrderCubit>(),
                      child: const OrderListScreen(),
                    ),
                  ),
                ).then((_) {
                  if (context.mounted) {
                    context.read<DashboardCubit>().loadDashboard();
                  }
                });
              },
              child: Text(
                'Lihat Semua',
                style: AppTypography.labelMedium.copyWith(
                  color: AppThemeColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (state is DashboardLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                color: AppThemeColors.primary,
              ),
            ),
          )
        else if (recentOrders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.lgRadius,
              boxShadow: AppShadows.small,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: AppThemeColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Belum ada penjualan hari ini',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppThemeColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...recentOrders.map((order) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: OrderCard(
                  order: order,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<OrderCubit>(),
                          child: OrderDetailScreen(orderId: order.id!),
                        ),
                      ),
                    ).then((_) {
                      if (context.mounted) {
                        context.read<DashboardCubit>().loadDashboard();
                      }
                    });
                  },
                ),
              )),
      ],
    );
  }
}
