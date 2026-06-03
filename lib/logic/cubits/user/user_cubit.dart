import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/data/models/user.dart';
import 'package:kreatif_pos/data/repositories/user_repository.dart';
import 'package:kreatif_pos/logic/cubits/user/user_state.dart';
import 'package:kreatif_pos/core/constants/app_constants.dart';

class UserCubit extends Cubit<UserState> {
  final UserRepository _userRepository;
  List<User> _users = [];

  UserCubit({UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepository(),
        super(const UserInitial());

  List<User> get users => _users;

  /// Load all users
  Future<void> loadUsers() async {
    emit(const UserLoading());

    try {
      _users = await _userRepository.getAllUsers();
      emit(UserLoaded(_users));
    } catch (e) {
      emit(UserError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Create new user
  Future<void> createUser({
    required String username,
    required String password,
    required String name,
    required UserRole role,
    bool canAccessSuppliers = false,
    bool canAccessItems = false,
  }) async {
    if (AppConstants.isDemoMode && _users.length >= 2) {
      emit(const UserError('Anda telah melebihi batas transaksi aplikasi demo, silakan beli hubungi Sales Kreatif atau ke 081932701147'));
      emit(UserLoaded(_users)); // Reset state
      return;
    }

    emit(const UserLoading());

    try {
      await _userRepository.createUser(
        username: username,
        password: password,
        name: name,
        role: role,
        canAccessSuppliers: canAccessSuppliers,
        canAccessItems: canAccessItems,
      );

      emit(const UserOperationSuccess('User berhasil ditambahkan'));

      // Reload users
      await loadUsers();
    } catch (e) {
      emit(UserError(e.toString().replaceAll('Exception: ', '')));
      // Re-emit loaded state to recover
      emit(UserLoaded(_users));
    }
  }

  /// Update user
  Future<void> updateUser({
    required int id,
    required String name,
    required UserRole role,
    bool canAccessSuppliers = false,
    bool canAccessItems = false,
  }) async {
    emit(const UserLoading());

    try {
      await _userRepository.updateUser(
        id: id,
        name: name,
        role: role,
        canAccessSuppliers: canAccessSuppliers,
        canAccessItems: canAccessItems,
      );

      emit(const UserOperationSuccess('User berhasil diupdate'));

      // Reload users
      await loadUsers();
    } catch (e) {
      emit(UserError(e.toString().replaceAll('Exception: ', '')));
      // Re-emit loaded state to recover
      emit(UserLoaded(_users));
    }
  }

  /// Reset user password
  Future<void> resetPassword({
    required int userId,
    required String newPassword,
  }) async {
    emit(const UserLoading());

    try {
      await _userRepository.resetPassword(
        userId: userId,
        newPassword: newPassword,
      );

      emit(const UserOperationSuccess('Password berhasil direset'));

      // Re-emit loaded state
      emit(UserLoaded(_users));
    } catch (e) {
      emit(UserError(e.toString().replaceAll('Exception: ', '')));
      // Re-emit loaded state to recover
      emit(UserLoaded(_users));
    }
  }

  /// Toggle user active status
  Future<void> toggleUserStatus(int id) async {
    try {
      final isActive = await _userRepository.toggleUserStatus(id);
      final message = isActive ? 'User diaktifkan' : 'User dinonaktifkan';

      emit(UserOperationSuccess(message));

      // Reload users
      await loadUsers();
    } catch (e) {
      emit(UserError(e.toString().replaceAll('Exception: ', '')));
      // Re-emit loaded state to recover
      emit(UserLoaded(_users));
    }
  }
}
