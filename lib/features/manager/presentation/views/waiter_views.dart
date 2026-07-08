import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../providers/manager_providers.dart';

class WaiterListView extends ConsumerStatefulWidget {
  const WaiterListView({super.key});

  @override
  ConsumerState<WaiterListView> createState() => _WaiterListViewState();
}

class _WaiterListViewState extends ConsumerState<WaiterListView> {
  String _searchQuery = "";

  void _showAddEditWaiterDialog({WaiterModel? waiter}) {
    final isEditing = waiter != null;
    final nameController = TextEditingController(text: waiter?.name ?? '');
    String status = waiter?.status ?? 'active';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(isEditing ? "Edit Waiter Details" : "Add New Waiter", style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Waiter Name",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: "Status",
                      prefixIcon: Icon(Icons.check_circle_outline),
                    ),
                    items: const [
                      DropdownMenuItem(value: "active", child: Text("Active")),
                      DropdownMenuItem(value: "inactive", child: Text("Inactive")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          status = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Name cannot be empty"), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    Navigator.pop(context);

                    final messenger = ScaffoldMessenger.of(context);
                    if (isEditing) {
                      final updated = waiter.copyWith(name: name, status: status);
                      await ref.read(managerActionProvider.notifier).editWaiter(updated);
                    } else {
                      final newWaiter = WaiterModel(
                        id: '',
                        name: name,
                        status: status,
                        createdAt: DateTime.now(),
                      );
                      await ref.read(managerActionProvider.notifier).addWaiter(newWaiter);
                    }

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? "Waiter updated successfully!" : "Waiter added successfully!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text(isEditing ? "SAVE CHANGES" : "ADD WAITER"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onToggleStatus(WaiterModel waiter) async {
    final updated = waiter.copyWith(status: waiter.status == "active" ? "inactive" : "active");
    await ref.read(managerActionProvider.notifier).editWaiter(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Waiter status updated to ${updated.status.toUpperCase()}"),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _onDeleteWaiter(WaiterModel waiter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Waiter", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to permanently delete '${waiter.name}'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("DELETE"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await ref.read(managerActionProvider.notifier).deleteWaiter(waiter.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Waiter deleted successfully"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitersState = ref.watch(waitersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Waiter Management"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        tooltip: "Add Waiter",
        onPressed: () => _showAddEditWaiterDialog(),
        child: const Icon(Icons.add),
      ),
      body: waitersState.when(
        loading: () => const LoadingWidget(message: "Loading waiters list..."),
        error: (err, _) => CustomErrorWidget(message: err.toString(), onRetry: () => ref.refresh(waitersStreamProvider)),
        data: (waiters) {
          final filtered = waiters.where((w) {
            return w.name.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SearchBarWidget(
                      placeholder: "Search waiters by name...",
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restaurant, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text("No Waiters Found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(_searchQuery.isNotEmpty ? "Try adjusting your search criteria" : "Click '+' to add a waiter", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
                            return GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 3.5,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final w = filtered[index];
                                final isActive = w.status == "active";
                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: isActive ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade100,
                                          child: Icon(Icons.person, color: isActive ? AppTheme.primaryColor : Colors.grey),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                w.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  w.status.toUpperCase(),
                                                  style: TextStyle(
                                                    color: isActive ? Colors.green : Colors.red,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isActive ? Icons.toggle_on : Icons.toggle_off,
                                            color: isActive ? Colors.green : Colors.grey,
                                            size: 28,
                                          ),
                                          tooltip: isActive ? "Deactivate" : "Activate",
                                          onPressed: () => _onToggleStatus(w),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          tooltip: "Edit",
                                          onPressed: () => _showAddEditWaiterDialog(waiter: w),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          tooltip: "Delete",
                                          onPressed: () => _onDeleteWaiter(w),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
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
