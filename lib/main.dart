import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/core/utils/date_formatter.dart';
import 'package:kreatif_klinik/data/database/database_helper.dart';
import 'package:kreatif_klinik/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_klinik/presentation/screens/auth/login_screen.dart';
import 'package:kreatif_klinik/presentation/screens/main_screen.dart';
import 'package:kreatif_klinik/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:kreatif_klinik/data/repositories/auth_repository.dart';
import 'package:kreatif_klinik/data/repositories/customer_repository.dart';
import 'package:kreatif_klinik/data/repositories/order_repository.dart';
import 'package:kreatif_klinik/data/repositories/report_repository.dart';
import 'package:kreatif_klinik/data/repositories/service_repository.dart';
import 'package:kreatif_klinik/data/repositories/user_repository.dart';
import 'package:kreatif_klinik/data/repositories/supplier_repository.dart';
import 'package:kreatif_klinik/data/repositories/purchase_order_repository.dart';
import 'package:kreatif_klinik/data/repositories/product_repository.dart';
import 'package:kreatif_klinik/data/repositories/unit_repository.dart';
import 'package:kreatif_klinik/data/repositories/payment_repository.dart'; // Add import
import 'package:kreatif_klinik/logic/cubits/order/order_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/unit/unit_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/product/product_cubit.dart';
import 'package:kreatif_klinik/core/services/notification_service.dart';
import 'package:kreatif_klinik/data/repositories/pengumuman_template_repository.dart';
import 'package:kreatif_klinik/data/repositories/stock_transfer_repository.dart';
import 'package:kreatif_klinik/logic/cubits/pengumuman/pengumuman_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/stock_transfer/stock_transfer_cubit.dart';
import 'package:kreatif_klinik/core/services/sync_service.dart';
import 'package:kreatif_klinik/logic/sync/sync_cubit.dart';
import 'package:kreatif_klinik/core/api/api_service.dart';
import 'package:kreatif_klinik/logic/cubits/customer/customer_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/supplier/supplier_cubit.dart';
import 'package:kreatif_klinik/data/repositories/doctor_repository.dart';
import 'package:kreatif_klinik/data/repositories/registration_repository.dart';
import 'package:kreatif_klinik/data/repositories/examination_repository.dart';
import 'package:kreatif_klinik/logic/cubits/doctor/doctor_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/registration/registration_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for Windows
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize all at once
  final results = await Future.wait([
    SharedPreferences.getInstance(),
    DateFormatter.initialize(),
    DatabaseHelper.instance.database,
    NotificationService().init(),
  ]);

  final prefs = results[0] as SharedPreferences;
  final showOnboarding = !(prefs.getBool('onboarding_complete') ?? false);

  runApp(MyApp(showOnboarding: showOnboarding));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;

  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => ServiceRepository()),
        RepositoryProvider(create: (_) => OrderRepository()),
        RepositoryProvider(create: (_) => CustomerRepository()),
        RepositoryProvider(create: (_) => ReportRepository()),
        RepositoryProvider(create: (_) => UserRepository()),
        RepositoryProvider(create: (_) => SupplierRepository()),
        RepositoryProvider(create: (_) => PurchaseOrderRepository()),
        RepositoryProvider(create: (_) => ProductRepository()),         
        RepositoryProvider(create: (_) => PaymentRepository()), // Add PaymentRepository
        RepositoryProvider(create: (_) => PengumumanTemplateRepository()),
        RepositoryProvider(create: (_) => StockTransferRepository()),
        RepositoryProvider(create: (_) => UnitRepository()),
        RepositoryProvider(create: (_) => DoctorRepository()),
        RepositoryProvider(create: (_) => RegistrationRepository()),
        RepositoryProvider(create: (_) => ExaminationRepository()),
        RepositoryProvider(
          create: (context) => SyncService(
            apiService: ApiService(),
            dbHelper: DatabaseHelper.instance,
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthCubit(
              authRepository: context.read<AuthRepository>(),
            )..checkAuthStatus(),
          ),
          BlocProvider(
            create: (context) => OrderCubit(
              orderRepository: context.read<OrderRepository>(),
              productRepository: context.read<ProductRepository>(),
              customerRepository: context.read<CustomerRepository>(), // Inject CustomerRepository
              paymentRepository: context.read<PaymentRepository>(), // Inject PaymentRepository
            )..loadOrders(),
          ),
          BlocProvider(
            create: (context) => PengumumanCubit(
              repository: context.read<PengumumanTemplateRepository>(),
            )..loadTemplates(),
          ),
          BlocProvider(
            create: (context) => StockTransferCubit(
              repository: context.read<StockTransferRepository>(),
            )..loadTransfers(),
          ),
          BlocProvider(
            create: (context) => ProductCubit(
              context.read<ProductRepository>(),
            )..loadProducts(),
          ),
          BlocProvider(
            create: (context) => SyncCubit(
              context.read<SyncService>(),
            ),
          ),
          BlocProvider(
            create: (context) => UnitCubit(
              context.read<UnitRepository>(),
            )..loadUnits(),
          ),
          BlocProvider(
            create: (context) => CustomerCubit(
              customerRepository: context.read<CustomerRepository>(),
            )..loadCustomers(),
          ),
          BlocProvider(
            create: (context) => SupplierCubit(
              supplierRepository: context.read<SupplierRepository>(),
            )..loadSuppliers(),
          ),
          BlocProvider(
            create: (context) => DoctorCubit(
              context.read<DoctorRepository>(),
            )..loadDoctors(),
          ),
          BlocProvider(
            create: (context) => RegistrationCubit(
              context.read<RegistrationRepository>(),
            )..loadRegistrations(),
          ),
        ],
        child: MaterialApp(
          title: 'Klinik Offline',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: AuthWrapper(showOnboarding: showOnboarding),
        ),
      ),
    );
  }
}

/// Wrapper widget that handles auth state changes
class AuthWrapper extends StatefulWidget {
  final bool showOnboarding;

  const AuthWrapper({super.key, required this.showOnboarding});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding;
  }

  void _onOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        // Show loading indicator while checking auth status
        if (state is AuthInitial || state is AuthLoading) {
          return Scaffold(
            backgroundColor: AppThemeColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.xlRadius,
                      boxShadow: AppShadows.medium,
                    ),
                    child: Image.asset(
                      'assets/icons/logoklinik.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const CircularProgressIndicator(
                    color: AppThemeColors.primary,
                  ),
                ],
              ),
            ),
          );
        }

        // Show main screen if authenticated
        if (state is AuthAuthenticated) {
          return MainScreen();
        }

        // Show login screen if not authenticated
        return const LoginScreen();
      },
    );
  }
}
