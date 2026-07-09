import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../providers/auth_providers.dart';

// --- Login Screen ---
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate credentials if Remember Me was selected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cached = ref.read(rememberMeProvider);
      if (cached['remember'] == 'true') {
        setState(() {
          _emailController.text = cached['email'] ?? '';
          _passwordController.text = cached['password'] ?? '';
          _rememberMe = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      try {
        await ref.read(authActionProvider.notifier).login(email, password, _rememberMe);
        final loginState = ref.read(authActionProvider);
        if (loginState.hasError) {
          _showError(loginState.error.toString());
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  void _showError(String err) {
    String cleanErr = err.replaceAll("Exception: ", "");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanErr),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Forgot Password (Manager Only)",
        message: "Enter your registered manager email address. Cashiers and Expediters must contact the manager to reset passwords.",
        inputLabel: "Email Address",
        inputPlaceholder: "manager@example.com",
        inputController: emailController,
        confirmLabel: "Send Reset Link",
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        final email = emailController.text.trim();
        if (email.isNotEmpty) {
          try {
            await ref.read(authActionProvider.notifier).forgotPassword(email);
            final actionState = ref.read(authActionProvider);
            if (actionState.hasError) {
              _showError(actionState.error.toString());
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Password reset email sent. Check your inbox or spam."),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            _showError(e.toString());
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final actionState = ref.watch(authActionProvider);

    Widget formWidget = Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(32.0),
        child: Card(
          elevation: isDesktop ? 4 : 0,
          color: Colors.white,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/logo1.png',
                    height: 200,
                    errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.primaryColor,
                      child: Icon(Icons.restaurant, size: 40, color: Colors.white),
                    ),
                  ),
                  // const SizedBox(height: 12),
                  // const Text(
                  //   "BOSS FOOD CORNER",
                  //   textAlign: .center,
                  //   style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor, letterSpacing: 1),
                  // ),
                  // const Text(
                  //   "POS Management Portal",
                  //   textAlign: .center,
                  //   style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                  // ),
                  // const SizedBox(height: 24),
                  CustomTextField(
                    label: "Email Address",
                    placeholder: "e.g., ali@example.com",
                    controller: _emailController,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return "Email is required";
                      final reg = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                      if (!reg.hasMatch(val)) return "Enter a valid email address";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: "Password",
                    placeholder: "Enter password",
                    controller: _passwordController,
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Password is required";
                      if (val.length < 6) return "Password must be at least 6 characters";
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Row(
                      //   children: [
                      //     Checkbox(
                      //       value: _rememberMe,
                      //       activeColor: AppTheme.primaryColor,
                      //       onChanged: (val) {
                      //         setState(() {
                      //           _rememberMe = val ?? false;
                      //         });
                      //       },
                      //     ),
                      //     const Text("Remember Me", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      //   ],
                      // ),
                      TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text("Forgot Password?"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // const Text(
                  //   "Forgot your password? Employees/Cashiers: Contact your manager to reset it.",
                  //   style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                  //   textAlign: .center,
                  // ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: "SIGN IN",
                    isLoading: actionState.isLoading,
                    onPressed: _onLogin,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/boss_icon.png',
                          height: 300,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.restaurant_menu,
                            size: 150,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Container(
                color: AppTheme.backgroundColor,
                child: SingleChildScrollView(
                  child: Center(child: formWidget),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: size.height,
          ),
          child: formWidget,
        ),
      ),
    );
  }
}

// --- First-Time Manager Setup Registration ---
class RegistrationView extends ConsumerStatefulWidget {
  const RegistrationView({super.key});

  @override
  ConsumerState<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends ConsumerState<RegistrationView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onRegister() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final phone = _phoneController.text.trim();

      try {
        await ref.read(authActionProvider.notifier).registerManager(
              name: name,
              email: email,
              password: password,
              phone: phone,
            );
        final regState = ref.read(authActionProvider);
        if (regState.hasError) {
          _showError(regState.error.toString());
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  void _showError(String err) {
    String cleanErr = err.replaceAll("Exception: ", "");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanErr),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final actionState = ref.watch(authActionProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size.height),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 550),
              padding: const EdgeInsets.all(24.0),
              child: Card(
              elevation: 4,
              color: Colors.white,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Prominent Setup Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.stars, color: Colors.white, size: 36),
                          SizedBox(height: 8),
                          Text(
                            "FIRST-TIME MANAGER SETUP",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Initialize the primary manager account for Boss Food Corner.",
                            textAlign: .center,
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          )
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CustomTextField(
                            label: "Full Name",
                            placeholder: "e.g., Ali Khan",
                            controller: _nameController,
                            prefixIcon: Icons.person_outline,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return "Full Name is required";
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: "Email Address",
                            placeholder: "e.g., manager@boss.com",
                            controller: _emailController,
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return "Email is required";
                              final reg = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                              if (!reg.hasMatch(val)) return "Enter a valid email address";
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: "Phone Number (11 Digits)",
                            placeholder: "e.g., 03001234567",
                            controller: _phoneController,
                            prefixIcon: Icons.phone_android,
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return "Phone number is required";
                              final clean = val.trim();
                              if (clean.length != 11 || !clean.startsWith("03") || double.tryParse(clean) == null) {
                                return "Enter a valid 11 digit Pakistani number (03XXXXXXXXX)";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: "Password (min 6 characters)",
                            placeholder: "Choose password",
                            controller: _passwordController,
                            prefixIcon: Icons.lock_outline,
                            isPassword: true,
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Password is required";
                              if (val.length < 6) return "Password must be at least 6 characters";
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: "Confirm Password",
                            placeholder: "Re-enter password",
                            controller: _confirmPasswordController,
                            prefixIcon: Icons.lock_clock_outlined,
                            isPassword: true,
                            validator: (val) {
                              if (val != _passwordController.text) return "Passwords do not match";
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          CustomButton(
                            text: "COMPLETE SETUP",
                            isLoading: actionState.isLoading,
                            onPressed: _onRegister,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

// --- Change Password Screen ---
class ChangePasswordView extends ConsumerStatefulWidget {
  const ChangePasswordView({super.key});

  @override
  ConsumerState<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends ConsumerState<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmNewController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmNewController.dispose();
    super.dispose();
  }

  void _onChangePassword() async {
    if (_formKey.currentState!.validate()) {
      final current = _currentController.text;
      final newPass = _newController.text;

      try {
        await ref.read(authActionProvider.notifier).changePassword(current, newPass);
        final changeState = ref.read(authActionProvider);
        if (changeState.hasError) {
          _showError(changeState.error.toString());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Password changed successfully! Redirecting..."),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Router redirect logic will automatically push the user to the proper dashboard
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  void _showError(String err) {
    String cleanErr = err.replaceAll("Exception: ", "");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanErr),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(authActionProvider);

    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size.height),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.shield_outlined, color: AppTheme.primaryColor, size: 54),
                    const SizedBox(height: 12),
                    const Text(
                      "FORCE PASSWORD CHANGE",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor, letterSpacing: 0.5),
                      textAlign: .center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "A password reset was requested by your manager. You must change your temporary password before accessing the system.",
                      style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                      textAlign: .center,
                    ),
                    const SizedBox(height: 24),
                    CustomTextField(
                      label: "Current Password (Temporary)",
                      placeholder: "Enter temporary password",
                      controller: _currentController,
                      prefixIcon: Icons.lock_person_outlined,
                      isPassword: true,
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Current password is required";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: "New Password (min 6 characters)",
                      placeholder: "Enter new password",
                      controller: _newController,
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      validator: (val) {
                        if (val == null || val.isEmpty) return "New password is required";
                        if (val.length < 6) return "Password must be at least 6 characters";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: "Confirm New Password",
                      placeholder: "Re-enter new password",
                      controller: _confirmNewController,
                      prefixIcon: Icons.lock_clock_outlined,
                      isPassword: true,
                      validator: (val) {
                        if (val != _newController.text) return "Passwords do not match";
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: "SAVE & PROCEED",
                      isLoading: actionState.isLoading,
                      onPressed: _onChangePassword,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => ref.read(authActionProvider.notifier).logout(),
                      child: const Text("CANCEL & LOGOUT", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    ),
    );
  }
}
