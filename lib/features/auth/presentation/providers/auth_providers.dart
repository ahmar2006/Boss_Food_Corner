import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/models/models.dart';
import '../../../../core/repositories/repositories.dart';

// Stream of currently logged in user
final authStateProvider = StreamProvider<UserModel?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.watchCurrentUser();
});

// Future to check if a manager is registered
final hasManagerProvider = FutureProvider.autoDispose<bool>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return await repo.hasManager();
});

// Cache manager status for instant routing guards check
class ManagerExistsCacheNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
}

final managerExistsCacheProvider = NotifierProvider<ManagerExistsCacheNotifier, bool>(ManagerExistsCacheNotifier.new);

// Credentials caching for "Remember Me"
class RememberMeNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    _loadCredentials();
    return {'email': '', 'password': '', 'remember': 'false'};
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    if (remember) {
      state = {
        'email': prefs.getString('cached_email') ?? '',
        'password': prefs.getString('cached_password') ?? '',
        'remember': 'true',
      };
    }
  }

  Future<void> saveCredentials(String email, String password, bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', remember);
    if (remember) {
      await prefs.setString('cached_email', email);
      await prefs.setString('cached_password', password);
      state = {'email': email, 'password': password, 'remember': 'true'};
    } else {
      await prefs.remove('cached_email');
      await prefs.remove('cached_password');
      state = {'email': '', 'password': '', 'remember': 'false'};
    }
  }

  Future<void> clearCacheOnLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    if (!remember) {
      await prefs.remove('cached_email');
      await prefs.remove('cached_password');
    }
  }
}

final rememberMeProvider = NotifierProvider<RememberMeNotifier, Map<String, String>>(() {
  return RememberMeNotifier();
});

// Notifier for Login/Register operations (Loading & Error state)
class AuthActionNotifier extends Notifier<AsyncValue<UserModel?>> {
  @override
  AsyncValue<UserModel?> build() => const AsyncValue.data(null);

  Future<void> login(String email, String password, bool remember) async {
    state = const AsyncValue.loading();
    try {
      final user = await ref.read(authRepositoryProvider).login(email, password);
      if (user != null) {
        await ref.read(rememberMeProvider.notifier).saveCredentials(email, password, remember);
      }
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> registerManager({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await ref.read(authRepositoryProvider).registerManager(name, email, password, phone);
      // Set cache manager to true since manager is now registered
      ref.read(managerExistsCacheProvider.notifier).state = true;
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).changePassword(currentPassword, newPassword);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> forgotPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).logout();
      await ref.read(rememberMeProvider.notifier).clearCacheOnLogout();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final authActionProvider = NotifierProvider<AuthActionNotifier, AsyncValue<UserModel?>>(() {
  return AuthActionNotifier();
});
