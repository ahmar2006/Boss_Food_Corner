import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../providers/manager_providers.dart';

// Safe image decoder widget
Widget buildBase64Image(String base64Str, {double size = 80, BoxFit fit = BoxFit.cover}) {
  if (base64Str.isEmpty) {
    return Container(
      height: size,
      width: size,
      color: Colors.grey.shade100,
      child: Icon(Icons.restaurant_menu, color: Colors.grey.shade400),
    );
  }
  try {
    final rawBase64 = base64Str.contains(',') ? base64Str.split(',')[1] : base64Str;
    final bytes = base64Decode(rawBase64);
    return Image.memory(
      bytes,
      height: size,
      width: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        height: size,
        width: size,
        color: Colors.grey.shade100,
        child: Icon(Icons.broken_image, color: Colors.grey.shade400),
      ),
    );
  } catch (_) {
    return Container(
      height: size,
      width: size,
      color: Colors.grey.shade100,
      child: Icon(Icons.broken_image, color: Colors.grey.shade400),
    );
  }
}

// --- Category List View ---
class CategoryListView extends ConsumerStatefulWidget {
  const CategoryListView({super.key});

  @override
  ConsumerState<CategoryListView> createState() => _CategoryListViewState();
}

class _CategoryListViewState extends ConsumerState<CategoryListView> {
  String _searchQuery = "";

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



  void _onDeleteCategory(CategoryModel cat) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Delete Category",
        message: "Are you sure you want to permanently delete category '${cat.name}'? All items within it will lose category association.",
        confirmLabel: "Delete Permanently",
        isDanger: true,
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ref.read(managerActionProvider.notifier).deleteCategory(cat.id);
          final actState = ref.read(managerActionProvider);
          if (actState.hasError) {
            _showError(actState.error.toString());
          }
        } catch (e) {
          _showError(e.toString());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesStreamProvider);
    final size = MediaQuery.of(context).size;
    final gridCount = size.width > 1200 ? 4 : (size.width > 800 ? 3 : 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Category Configuration"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        tooltip: "Add Category",
        onPressed: () => context.go('/manager/categories/add'),
        child: const Icon(Icons.add),
      ),
      body: categoriesState.when(
        loading: () => const LoadingWidget(message: "Loading categories..."),
        error: (err, _) => CustomErrorWidget(message: err.toString(), onRetry: () => ref.refresh(categoriesStreamProvider)),
        data: (categories) {
          final filtered = categories.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchBarWidget(
                  placeholder: "Search categories by name...",
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyStateWidget(
                          title: "No Categories Registered",
                          message: "Click the '+' button to configure menu categories.",
                          icon: Icons.category_outlined,
                        )
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final cat = filtered[idx];


                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        buildBase64Image(cat.imageBase64),
                                        // Visibility badge removed
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            cat.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                tooltip: "Edit Category",
                                                onPressed: () => context.go('/manager/categories/edit/${cat.id}'),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                tooltip: "Delete Category",
                                                onPressed: () => _onDeleteCategory(cat),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Category Add/Edit Form ---
class CategoryFormView extends ConsumerStatefulWidget {
  final String? categoryId;

  const CategoryFormView({super.key, this.categoryId});

  @override
  ConsumerState<CategoryFormView> createState() => _CategoryFormViewState();
}

class _CategoryFormViewState extends ConsumerState<CategoryFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _imageBase64 = "";

  bool _isEditing = false;
  CategoryModel? _existingCat;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.categoryId != null;
    if (_isEditing) {
      _loadCategory();
    }
  }

  void _loadCategory() {
    final list = ref.read(categoriesStreamProvider).value ?? [];
    try {
      _existingCat = list.firstWhere((c) => c.id == widget.categoryId);
      _nameController.text = _existingCat!.name;
      _imageBase64 = _existingCat!.imageBase64;

    } catch (_) {
      context.go('/manager/categories');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  void _onSave() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      const status = "active";

      try {
        if (_isEditing && _existingCat != null) {
          final updated = _existingCat!.copyWith(
            name: name,
            imageBase64: _imageBase64,
            status: status,
          );
          await ref.read(managerActionProvider.notifier).editCategory(updated);
        } else {
          await ref.read(managerActionProvider.notifier).addCategory(name, _imageBase64, status);
        }

        final actState = ref.read(managerActionProvider);
        if (actState.hasError) {
          _showError(actState.error.toString());
        } else {
          context.go('/manager/categories');
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(managerActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Category" : "Add Category"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/categories'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
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
                        _isEditing ? "Modify Category Profile" : "Configure Menu Category",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        textAlign: .center,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        label: "Category Name",
                        placeholder: "e.g., Fast Food, Drinks",
                        controller: _nameController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Category name is required";
                          if (val.trim().length < 2) return "Must be at least 2 characters";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ImagePickerWidget(
                        initialBase64: _imageBase64,
                        onImageSelected: (base64) {
                          _imageBase64 = base64;
                        },
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: _isEditing ? "SAVE UPDATES" : "CREATE CATEGORY",
                        isLoading: actionState.isLoading,
                        onPressed: _onSave,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: "CANCEL",
                        isOutlined: true,
                        color: Colors.grey,
                        onPressed: () => context.go('/manager/categories'),
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

// --- Menu Items List View ---
class MenuListView extends ConsumerStatefulWidget {
  const MenuListView({super.key});

  @override
  ConsumerState<MenuListView> createState() => _MenuListViewState();
}

class _MenuListViewState extends ConsumerState<MenuListView> {
  String _searchQuery = "";
  String _categoryFilter = "All"; // All or categoryId

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

  void _onToggleStatus(MenuItemModel item) async {
    final updated = item.copyWith(status: item.status == "active" ? "disabled" : "active");
    try {
      await ref.read(managerActionProvider.notifier).editMenuItem(updated);
      final actState = ref.read(managerActionProvider);
      if (actState.hasError) {
        _showError(actState.error.toString());
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _onDeleteMenuItem(MenuItemModel item) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Delete Menu Item",
        message: "Are you sure you want to permanently delete '${item.name}'?",
        confirmLabel: "Delete Permanently",
        isDanger: true,
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ref.read(managerActionProvider.notifier).deleteMenuItem(item.id);
          final actState = ref.read(managerActionProvider);
          if (actState.hasError) {
            _showError(actState.error.toString());
          }
        } catch (e) {
          _showError(e.toString());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuItemsState = ref.watch(menuItemsStreamProvider);
    final categoriesState = ref.watch(categoriesStreamProvider);

    final size = MediaQuery.of(context).size;
    final gridCount = size.width > 1200 ? 4 : (size.width > 800 ? 3 : 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Menu Configuration"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        tooltip: "Add Menu Item",
        onPressed: () => context.go('/manager/menu/add'),
        child: const Icon(Icons.add),
      ),
      body: menuItemsState.when(
        loading: () => const LoadingWidget(message: "Loading menu items..."),
        error: (err, _) => CustomErrorWidget(message: err.toString(), onRetry: () => ref.refresh(menuItemsStreamProvider)),
        data: (menuItems) {
          final categories = categoriesState.value ?? [];

          final filtered = menuItems.where((item) {
            final matchesQuery = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.description.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesCat = _categoryFilter == "All" || item.categoryId == _categoryFilter;
            return matchesQuery && matchesCat;
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filters
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SearchBarWidget(
                            placeholder: "Search menu items by name, description...",
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
                            value: _categoryFilter,
                            decoration: const InputDecoration(
                              labelText: "Category Filter",
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem(value: "All", child: Text("All Categories")),
                              ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            ],
                            onChanged: (val) {
                              setState(() {
                                _categoryFilter = val ?? "All";
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyStateWidget(
                          title: "No Menu Items Found",
                          message: "Configure items by clicking the '+' button.",
                          icon: Icons.restaurant_menu_outlined,
                        )
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.70,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final item = filtered[idx];
                            final isActive = item.status == "active";
                            final catName = categories.firstWhere((c) => c.id == item.categoryId,
                                orElse: () => CategoryModel(id: '', name: 'N/A', imageBase64: '', status: '', createdAt: DateTime.now(), updatedAt: DateTime.now())).name;

                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        buildBase64Image(item.imageBase64),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isActive ? Colors.green.shade600 : Colors.grey.shade600,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              isActive ? "ACTIVE" : "DISABLED",
                                              style: const TextStyle(
                                                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              catName,
                                              style: const TextStyle(
                                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    item.description,
                                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (item.variants.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Wrap(
                                                      spacing: 6,
                                                      runSpacing: 4,
                                                      children: item.variants.map((v) {
                                                        final priceStr = v.price != null && v.price! > 0 ? " (Rs. ${v.price!.toStringAsFixed(0)})" : "";
                                                        return Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey.shade100,
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(color: Colors.grey.shade300),
                                                          ),
                                                          child: Text(
                                                            "${v.name}$priceStr",
                                                            style: TextStyle(color: Colors.grey.shade800, fontSize: 9, fontWeight: FontWeight.bold),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item.price > 0
                                                    ? "Rs. ${item.price.toStringAsFixed(2)}"
                                                    : (item.variants.isNotEmpty ? " " : "Rs. 0.00"),
                                                style: const TextStyle(
                                                    color: AppTheme.primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14),
                                              ),
                                              Text(
                                                "${item.prepTime} Min",
                                                style: const TextStyle(
                                                    color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                tooltip: "Edit Item",
                                                onPressed: () => context.go('/manager/menu/edit/${item.id}'),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  isActive ? Icons.visibility_off : Icons.visibility,
                                                  color: isActive ? Colors.orange : Colors.green,
                                                  size: 20,
                                                ),
                                                tooltip: isActive ? "Hide Item" : "Show Item",
                                                onPressed: () => _onToggleStatus(item),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                tooltip: "Delete Item",
                                                onPressed: () => _onDeleteMenuItem(item),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Menu Item Add/Edit Form View ---
class MenuItemFormView extends ConsumerStatefulWidget {
  final String? itemId;

  const MenuItemFormView({super.key, this.itemId});

  @override
  ConsumerState<MenuItemFormView> createState() => _MenuItemFormViewState();
}

class _MenuItemFormViewState extends ConsumerState<MenuItemFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _prepController = TextEditingController();
  final _newVariantNameController = TextEditingController();
  final _newVariantPriceController = TextEditingController();

  String _selectedCatId = "";
  String _imageBase64 = "";
  bool _isActive = true;
  bool _isEditing = false;
  MenuItemModel? _existingItem;
  List<MenuItemVariant> _variants = [];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.itemId != null;
    if (_isEditing) {
      _loadItem();
    }
  }

  void _loadItem() {
    final list = ref.read(menuItemsStreamProvider).value ?? [];
    try {
      _existingItem = list.firstWhere((i) => i.id == widget.itemId);
      _nameController.text = _existingItem!.name;
      _descController.text = _existingItem!.description;
      _priceController.text = _existingItem!.price.toString();
      _prepController.text = _existingItem!.prepTime.toString();
      _selectedCatId = _existingItem!.categoryId;
      _imageBase64 = _existingItem!.imageBase64;
      _isActive = _existingItem!.status == "active";
      _variants = List<MenuItemVariant>.from(_existingItem!.variants);
    } catch (_) {
      context.go('/manager/menu');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _prepController.dispose();
    _newVariantNameController.dispose();
    _newVariantPriceController.dispose();
    super.dispose();
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

  void _onSave() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCatId.isEmpty) {
        _showError("A menu category must be selected");
        return;
      }

      final name = _nameController.text.trim();
      final desc = _descController.text.trim();
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final prep = int.parse(_prepController.text);
      final status = _isActive ? "active" : "disabled";

      final item = MenuItemModel(
        id: _isEditing ? _existingItem!.id : '',
        name: name,
        categoryId: _selectedCatId,
        description: desc,
        price: price,
        imageBase64: _imageBase64,
        prepTime: prep,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        variants: _variants,
      );

      try {
        if (_isEditing) {
          await ref.read(managerActionProvider.notifier).editMenuItem(item);
        } else {
          await ref.read(managerActionProvider.notifier).addMenuItem(item);
        }

        final actState = ref.read(managerActionProvider);
        if (actState.hasError) {
          _showError(actState.error.toString());
        } else {
          context.go('/manager/menu');
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(managerActionProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? [];
    final activeCats = categories.where((c) => c.status == "active").toList();

    // Auto-select category if empty
    if (_selectedCatId.isEmpty && activeCats.isNotEmpty) {
      _selectedCatId = activeCats.first.id;
    }

    // Ensure selected category is in items list to prevent Flutter dropdown crashes
    final dropdownItems = activeCats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList();
    if (_selectedCatId.isNotEmpty && !activeCats.any((c) => c.id == _selectedCatId)) {
      try {
        final cat = categories.firstWhere((c) => c.id == _selectedCatId);
        dropdownItems.add(DropdownMenuItem(value: cat.id, child: Text("${cat.name} (Inactive)")));
      } catch (_) {
        dropdownItems.add(DropdownMenuItem(value: _selectedCatId, child: const Text("Unknown Category")));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Menu Item" : "Add Menu Item"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/menu'),
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
                        _isEditing ? "Edit Food Details" : "Configure Menu Food Item",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        textAlign: .center,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        label: "Item Name",
                        placeholder: "e.g., Zinger Burger, Fries",
                        controller: _nameController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Item name is required";
                          if (val.trim().length < 2) return "Must be at least 2 characters";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Select Menu Category",
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedCatId.isEmpty ? null : _selectedCatId,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: dropdownItems,
                            onChanged: (val) {
                              setState(() {
                                _selectedCatId = val ?? "";
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: "Price (Rs.) (Optional)",
                        placeholder: "e.g., 450.00",
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return null;
                          final doubleVal = double.tryParse(val);
                          if (doubleVal == null || doubleVal < 0) return "Enter a valid price greater than or equal to 0";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: "Preparation Time (Minutes)",
                        placeholder: "e.g., 15",
                        controller: _prepController,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Preparation time is required";
                          final intVal = int.tryParse(val);
                          if (intVal == null || intVal < 1) return "Must be at least 1 minute";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: "Description",
                        placeholder: "Brief description of the item...",
                        controller: _descController,
                        maxLines: 3,
                        validator: (val) {
                          if (val != null && val.trim().length > 500) {
                            return "Description exceeds 500 characters limit.";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Optional Variants Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Item Sizes / Variants (Optional)",
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          if (_variants.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: _variants.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final variant = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(variant.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Row(
                                          children: [
                                            Text(
                                              variant.price != null ? "Rs. ${variant.price!.toStringAsFixed(0)}" : "Base Price",
                                              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                setState(() {
                                                  _variants.removeAt(idx);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _newVariantNameController,
                                  decoration: const InputDecoration(
                                    labelText: "Variant Name",
                                    hintText: "e.g. Small, 1.5L",
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _newVariantPriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: "Price",
                                    hintText: "Rs.",
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 36),
                                onPressed: () {
                                  final name = _newVariantNameController.text.trim();
                                  if (name.isEmpty) {
                                    _showError("Enter a variant name.");
                                    return;
                                  }
                                  final priceText = _newVariantPriceController.text.trim();
                                  if (priceText.isEmpty) {
                                    _showError("Enter a variant price.");
                                    return;
                                  }
                                  final priceVal = double.tryParse(priceText);
                                  if (priceVal == null || priceVal <= 0) {
                                    _showError("Enter a valid price greater than 0.");
                                    return;
                                  }
                                  setState(() {
                                    _variants.add(MenuItemVariant(name: name, price: priceVal));
                                    _newVariantNameController.clear();
                                    _newVariantPriceController.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ImagePickerWidget(
                        initialBase64: _imageBase64,
                        onImageSelected: (base64) {
                          _imageBase64 = base64;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Status Enabled",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _isActive,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (val) {
                              setState(() {
                                _isActive = val;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: _isEditing ? "SAVE UPDATES" : "CREATE MENU ITEM",
                        isLoading: actionState.isLoading,
                        onPressed: _onSave,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: "CANCEL",
                        isOutlined: true,
                        color: Colors.grey,
                        onPressed: () => context.go('/manager/menu'),
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
