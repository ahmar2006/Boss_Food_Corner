import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/repositories/repositories.dart';
import '../providers/manager_providers.dart';

// --- Employee List View ---
class EmployeeListView extends ConsumerStatefulWidget {
  const EmployeeListView({super.key});

  @override
  ConsumerState<EmployeeListView> createState() => _EmployeeListViewState();
}

class _EmployeeListViewState extends ConsumerState<EmployeeListView> {
  String _searchQuery = "";
  String _roleFilter = "All"; // All, cashier, expediter

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

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onToggleStatus(UserModel emp) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: emp.status == "active" ? "Disable Employee" : "Enable Employee",
        message: emp.status == "active"
            ? "Are you sure you want to disable ${emp.name}? They will be immediately blocked from logging in."
            : "Are you sure you want to enable ${emp.name}? They will be allowed to log in.",
        confirmLabel: emp.status == "active" ? "Disable" : "Enable",
        isDanger: emp.status == "active",
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ref.read(managerActionProvider.notifier).toggleEmployeeStatus(emp.uid, emp.status);
          final actState = ref.read(managerActionProvider);
          if (actState.hasError) {
            _showError(actState.error.toString());
          } else {
            _showSuccess("Employee ${emp.status == 'active' ? 'disabled' : 'enabled'} successfully.");
          }
        } catch (e) {
          _showError(e.toString());
        }
      }
    });
  }

  void _onResetPassword(UserModel emp) {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.password, color: AppTheme.secondaryColor),
            const SizedBox(width: 8),
            Text("Update Password: ${emp.name}"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              label: "New Password",
              placeholder: "At least 6 characters",
              controller: passController,
              isPassword: true,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              label: "Confirm New Password",
              placeholder: "Match new password",
              controller: confirmController,
              isPassword: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (passController.text.length < 6) {
                _showError("Password must be at least 6 characters");
                return;
              }
              if (passController.text != confirmController.text) {
                _showError("Passwords do not match");
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ref.read(managerActionProvider.notifier).resetEmployeePassword(emp.uid, passController.text);
          final actState = ref.read(managerActionProvider);
          if (actState.hasError) {
            _showError(actState.error.toString());
          } else {
            _showSuccess("Employee password updated successfully.");
          }
        } catch (e) {
          _showError(e.toString());
        }
      }
    });
  }

  void _onDeleteEmployee(UserModel emp) async {
    // Check order count first
    int count = 0;
    try {
      count = await ref.read(employeeRepositoryProvider).getEmployeeOrderCount(emp.uid);
    } catch (_) {}

    String warning = "Are you sure you want to permanently delete ${emp.name}?";
    if (count > 0) {
      warning += "\nWARNING: This employee has placed $count orders in history. Deleting their account will orphan these records.";
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Delete Employee permanently",
        message: warning,
        confirmLabel: "Delete Permanently",
        isDanger: true,
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ref.read(managerActionProvider.notifier).deleteEmployee(emp);
          final actState = ref.read(managerActionProvider);
          if (actState.hasError) {
            _showError(actState.error.toString());
          } else {
            _showSuccess("Employee permanently deleted.");
          }
        } catch (e) {
          _showError(e.toString());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final employeesState = ref.watch(employeesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Employee Management"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        tooltip: "Add Employee",
        onPressed: () => context.go('/manager/employees/add'),
        child: const Icon(Icons.add),
      ),
      body: employeesState.when(
        loading: () => const LoadingWidget(message: "Fetching employees..."),
        error: (err, _) => CustomErrorWidget(message: err.toString(), onRetry: () => ref.refresh(employeesStreamProvider)),
        data: (employees) {
          // Client-side search and filters
          final filtered = employees.where((emp) {
            final matchesQuery = emp.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                emp.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                emp.phone.contains(_searchQuery);
            final matchesRole = _roleFilter == "All" || emp.role.toLowerCase() == _roleFilter.toLowerCase();
            return matchesQuery && matchesRole;
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter bar
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SearchBarWidget(
                                placeholder: "Search employees by name, email or phone...",
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _roleFilter,
                                decoration: const InputDecoration(
                                  labelText: "Role Filter",
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(value: "All", child: Text("All Roles")),
                                  DropdownMenuItem(value: "cashier", child: Text("Cashier")),
                                  DropdownMenuItem(value: "expediter", child: Text("Expediter")),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _roleFilter = val ?? "All";
                                  });
                                },
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: SearchBarWidget(
                                placeholder: "Search employees by name, email or phone...",
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: _roleFilter,
                                decoration: const InputDecoration(
                                  labelText: "Role Filter",
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(value: "All", child: Text("All Roles")),
                                  DropdownMenuItem(value: "cashier", child: Text("Cashier")),
                                  DropdownMenuItem(value: "expediter", child: Text("Expediter")),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _roleFilter = val ?? "All";
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      }
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: filtered.isEmpty
                          ? const EmptyStateWidget(
                              title: "No Employees Found",
                              message: "Try modifying your search queries or filters.",
                              icon: Icons.people_outline,
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text("Name", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Email", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Phone", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Role", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: filtered.map((emp) {
                                    final isActive = emp.status == "active";
                                    final isCashier = emp.role == "cashier";
                                    return DataRow(cells: [
                                      DataCell(Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                                      DataCell(Text(emp.email)),
                                      DataCell(Text(emp.phone)),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isCashier ? Colors.blue.shade50 : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            emp.role.toUpperCase(),
                                            style: TextStyle(
                                                color: isCashier ? Colors.blue.shade700 : Colors.green.shade700,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            Container(
                                              height: 8,
                                              width: 8,
                                              decoration: BoxDecoration(
                                                color: isActive ? Colors.green : Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isActive ? "Active" : "Disabled",
                                              style: TextStyle(
                                                  color: isActive ? Colors.green : Colors.red,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              tooltip: "Edit Employee",
                                              onPressed: () => context.go('/manager/employees/edit/${emp.uid}'),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                isActive ? Icons.block : Icons.check_circle_outline,
                                                color: isActive ? Colors.orange : Colors.green,
                                              ),
                                              tooltip: isActive ? "Disable Account" : "Enable Account",
                                              onPressed: () => _onToggleStatus(emp),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.key, color: Colors.amber),
                                              tooltip: "Reset Password",
                                              onPressed: () => _onResetPassword(emp),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              tooltip: "Delete Account",
                                              onPressed: () => _onDeleteEmployee(emp),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Employee Add/Edit Form View ---
class EmployeeFormView extends ConsumerStatefulWidget {
  final String? employeeId;

  const EmployeeFormView({super.key, this.employeeId});

  @override
  ConsumerState<EmployeeFormView> createState() => _EmployeeFormViewState();
}

class _EmployeeFormViewState extends ConsumerState<EmployeeFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = "cashier";
  bool _isEditing = false;
  UserModel? _existingEmployee;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.employeeId != null;
    if (_isEditing) {
      _loadEmployee();
    }
  }

  void _loadEmployee() async {
    // We can fetch from stream list or request directly
    final employees = ref.read(employeesStreamProvider).value ?? [];
    try {
      _existingEmployee = employees.firstWhere((e) => e.uid == widget.employeeId);
      _nameController.text = _existingEmployee!.name;
      _emailController.text = _existingEmployee!.email;
      _phoneController.text = _existingEmployee!.phone;
      _selectedRole = _existingEmployee!.role;
    } catch (_) {
      // If not loaded yet, go back
      context.go('/manager/employees');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSave() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final role = _selectedRole;

      try {
        if (_isEditing && _existingEmployee != null) {
          final updated = _existingEmployee!.copyWith(
            name: name,
            phone: phone,
            role: role,
          );
          await ref.read(managerActionProvider.notifier).editEmployee(updated);
        } else {
          final password = _passwordController.text;
          await ref.read(managerActionProvider.notifier).addEmployee(name, email, password, phone, role);
        }

        final actState = ref.read(managerActionProvider);
        if (actState.hasError) {
          _showError(actState.error.toString());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing ? "Employee profile updated." : "Employee created successfully."),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/manager/employees');
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
    final actionState = ref.watch(managerActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Employee" : "Add Employee"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/employees'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isEditing ? "Update Credentials" : "Create New Employee Profile",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        textAlign: .center,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        label: "Full Name",
                        placeholder: "e.g., Ali Khan",
                        controller: _nameController,
                        prefixIcon: Icons.person_outline,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Name is required";
                          if (val.trim().length < 3) return "Name must be at least 3 characters";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: "Email Address",
                        placeholder: "e.g., cashier@boss.com",
                        controller: _emailController,
                        prefixIcon: Icons.email_outlined,
                        readOnly: _isEditing,
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
                        label: "Phone Number",
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
                      if (!_isEditing) ...[
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: "Password",
                          placeholder: "At least 6 characters",
                          controller: _passwordController,
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Password is required";
                            if (val.length < 6) return "Password must be at least 6 characters";
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Select System Role",
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(value: "cashier", child: Text("Cashier")),
                              DropdownMenuItem(value: "expediter", child: Text("Expediter")),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedRole = val ?? "cashier";
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: _isEditing ? "SAVE UPDATES" : "CREATE EMPLOYEE",
                        isLoading: actionState.isLoading,
                        onPressed: _onSave,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: "CANCEL",
                        isOutlined: true,
                        color: Colors.grey,
                        onPressed: () => context.go('/manager/employees'),
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
