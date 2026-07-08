import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../providers/manager_providers.dart';

class RiderListView extends ConsumerStatefulWidget {
  const RiderListView({super.key});

  @override
  ConsumerState<RiderListView> createState() => _RiderListViewState();
}

class _RiderListViewState extends ConsumerState<RiderListView> {
  String _searchQuery = "";

  void _showAddEditRiderDialog({RiderModel? rider}) {
    final isEditing = rider != null;
    final nameController = TextEditingController(text: rider?.name ?? '');
    final phoneController = TextEditingController(text: rider?.phone ?? '');
    String status = rider?.status ?? 'active';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(isEditing ? "Edit Rider Details" : "Add New Rider", style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Rider Name",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      prefixIcon: Icon(Icons.phone),
                      hintText: "e.g., 03001234567",
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
                    final phone = phoneController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Name cannot be empty"), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Phone number cannot be empty"), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (phone.length != 11 || !phone.startsWith("03") || double.tryParse(phone) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Enter a valid 11 digit number (03XXXXXXXXX)"), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    Navigator.pop(context);

                    final messenger = ScaffoldMessenger.of(context);
                    if (isEditing) {
                      final updated = rider.copyWith(name: name, phone: phone, status: status);
                      await ref.read(managerActionProvider.notifier).editRider(updated);
                    } else {
                      final newRider = RiderModel(
                        id: '',
                        name: name,
                        phone: phone,
                        status: status,
                        createdAt: DateTime.now(),
                      );
                      await ref.read(managerActionProvider.notifier).addRider(newRider);
                    }

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? "Rider updated successfully!" : "Rider added successfully!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text(isEditing ? "SAVE CHANGES" : "ADD RIDER"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onToggleStatus(RiderModel rider) async {
    final updated = rider.copyWith(status: rider.status == "active" ? "inactive" : "active");
    await ref.read(managerActionProvider.notifier).editRider(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rider status updated to ${updated.status.toUpperCase()}"),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _onDeleteRider(RiderModel rider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Rider", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to permanently delete '${rider.name}'?"),
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
      await ref.read(managerActionProvider.notifier).deleteRider(rider.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rider deleted successfully"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ridersState = ref.watch(ridersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rider Management"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        tooltip: "Add Rider",
        onPressed: () => _showAddEditRiderDialog(),
        child: const Icon(Icons.add),
      ),
      body: ridersState.when(
        loading: () => const LoadingWidget(message: "Loading riders list..."),
        error: (err, _) => CustomErrorWidget(message: err.toString(), onRetry: () => ref.refresh(ridersStreamProvider)),
        data: (riders) {
          final filtered = riders.where((r) {
            return r.name.toLowerCase().contains(_searchQuery.toLowerCase()) || r.phone.contains(_searchQuery);
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
                      placeholder: "Search riders by name or phone...",
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
                              Icon(Icons.delivery_dining, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text("No Riders Found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(_searchQuery.isNotEmpty ? "Try adjusting your search criteria" : "Click '+' to add a rider", style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                                childAspectRatio: 3.2,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final r = filtered[index];
                                final isActive = r.status == "active";
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
                                          child: Icon(Icons.delivery_dining, color: isActive ? AppTheme.primaryColor : Colors.grey),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                r.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                r.phone,
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  r.status.toUpperCase(),
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
                                          onPressed: () => _onToggleStatus(r),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          tooltip: "Edit",
                                          onPressed: () => _showAddEditRiderDialog(rider: r),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          tooltip: "Delete",
                                          onPressed: () => _onDeleteRider(r),
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
