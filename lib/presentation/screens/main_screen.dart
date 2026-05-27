import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/core/theme/app_theme.dart';
import 'package:kreatif_pos/data/models/user.dart';
import 'package:kreatif_pos/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_pos/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_pos/logic/cubits/order/order_cubit.dart';
import 'package:kreatif_pos/logic/cubits/user/user_cubit.dart';
import 'package:kreatif_pos/logic/cubits/report/report_cubit.dart';
import 'package:kreatif_pos/logic/cubits/dashboard/dashboard_cubit.dart';
import 'package:kreatif_pos/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:kreatif_pos/presentation/screens/reports/report_screen.dart';
import 'package:kreatif_pos/presentation/screens/settings/settings_screen.dart';
import 'package:kreatif_pos/presentation/screens/pos/pos_screen.dart';
import 'package:kreatif_pos/presentation/screens/orders/order_list_screen.dart';
import 'package:kreatif_pos/logic/cubits/pos/pos_cubit.dart';
import 'package:kreatif_pos/logic/cubits/supplier/supplier_cubit.dart';
import 'package:kreatif_pos/presentation/screens/purchasing/purchase_order_list_screen.dart';
import 'package:kreatif_pos/logic/cubits/purchase_order/purchase_order_cubit.dart';
import 'package:kreatif_pos/data/repositories/product_repository.dart';
import 'package:kreatif_pos/data/repositories/purchase_order_repository.dart';
import 'package:kreatif_pos/data/repositories/supplier_repository.dart';
import 'package:kreatif_pos/data/repositories/customer_repository.dart';
import 'package:kreatif_pos/data/repositories/order_repository.dart';
import 'package:kreatif_pos/data/repositories/payment_repository.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late OrderCubit _orderCubit;
  late DashboardCubit _dashboardCubit;
  late ReportCubit _reportCubit;
  late UserCubit _userCubit;
  PosCubit? _posCubit;

  @override
  void initState() {
    super.initState();
    _dashboardCubit = DashboardCubit()..loadDashboard();
    _orderCubit = OrderCubit(
      productRepository: context.read<ProductRepository>(),
      orderRepository: context.read<OrderRepository>(),
      customerRepository: context.read<CustomerRepository>(),
      paymentRepository: context.read<PaymentRepository>(),
    )..loadOrders();
    _reportCubit = ReportCubit();
    _userCubit = UserCubit();
  }

  @override
  void dispose() {
    _orderCubit.close();
    _dashboardCubit.close();
    _reportCubit.close();
    _userCubit.close();
    _posCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = state.user;
        final isOwner = user.role == UserRole.owner;

        // Build navigation items based on role
        final navItems = <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ];

        final isLargeScreen = MediaQuery.of(context).size.width > 800;

        if (isOwner || user.role == UserRole.kasir) {
          navItems.add(
            BottomNavigationBarItem(
              icon: Icon(isLargeScreen ? Icons.point_of_sale_outlined : Icons.receipt_long_outlined),
              activeIcon: Icon(isLargeScreen ? Icons.point_of_sale : Icons.receipt_long),
              label: isLargeScreen ? 'Kasir' : 'Penjualan',
            ),
          );
        }





        if (isOwner) {
          navItems.add(
            const BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              activeIcon: Icon(Icons.shopping_bag),
              label: 'Pembelian',
            ),
          );

          navItems.add(
            const BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Laporan',
            ),
          );
        
          navItems.add(
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          );
        }

        // Build screens list based on role
        final screens = <Widget>[
          BlocProvider.value(
            value: _dashboardCubit,
            child: BlocProvider.value(
              value: _orderCubit,
              child: DashboardScreen(
                onSwitchTab: (index) {
                  // Determine actual index based on role logic
                  int targetIndex = index;
                  
                  // If user is owner or cashier, index 1 is Sales
                  // If user is owner, index 2 is Purchasing
                  
                  // However, the navItems list is built dynamically. 
                  // We need to ensure the index matches the navItems list.
                  // Standard mapping: 
                  // 1 -> Sales (Kasir)
                  // 2 -> Purchasing (Pembelian)
                  
                  setState(() => _currentIndex = targetIndex);
                },
              ),
            ),
          ),
        ];

        if (isOwner || user.role == UserRole.kasir) {
          if (isLargeScreen) {
            // Add Klinik Screen for large screens
            // Initialize PosCubit if not already done
            _posCubit ??= PosCubit(context.read<ProductRepository>())..loadProducts();
            
            screens.add(
              BlocProvider.value(
                value: _posCubit!,
                child: const PosScreen(),
              ),
            );
          } else {
            // Add OrderListScreen for small screens
            screens.add(
              BlocProvider.value(
                value: _orderCubit,
                child: const OrderListScreen(),
              ),
            );
          }
        }





        if (isOwner) {
          // Add Pembelian Screen
          screens.add(
            MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (context) => PurchaseOrderCubit(
                    repository: context.read<PurchaseOrderRepository>(),
                  )..loadPurchaseOrders(),
                ),
                // We also need SupplierCubit available for the Create Screen which is pushed from here
                BlocProvider(
                  create: (context) => SupplierCubit(
                   supplierRepository: context.read<SupplierRepository>(),
                  ),
                ),
              ],
              child: const PurchaseOrderListScreen(),
            ),
          );
          
          screens.add(
            BlocProvider.value(
              value: _reportCubit,
              child: const ReportScreen(),
            ),
          );
          screens.add(
            BlocProvider.value(
              value: _userCubit,
              child: const SettingsScreen(),
            ),
          );
        }

        // Ensure current index is valid
        if (_currentIndex >= screens.length) {
          _currentIndex = 0;
        }

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: _buildCustomBottomNav(navItems),
        );
      },
    );
  }

  Widget _buildCustomBottomNav(List<BottomNavigationBarItem> navItems) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = _currentIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _currentIndex = index);
                    // If switching to Klinik (Kasir) tab, reload products
                    if (item.label == 'Kasir') {
                      _posCubit?.loadProducts();
                    } else if (item.label == 'Dashboard') {
                         _dashboardCubit.loadDashboard();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconTheme(
                        data: IconThemeData(
                          color: isSelected
                              ? AppThemeColors.primary
                              : AppThemeColors.textSecondary,
                          size: 24,
                        ),
                        child: isSelected ? item.activeIcon : item.icon,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label ?? '',
                        style: AppTypography.labelSmall.copyWith(
                          color: isSelected
                              ? AppThemeColors.primary
                              : AppThemeColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
