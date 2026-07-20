import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

// ---------------------------------------------------------------------------
// Receipt logo cache — loaded ONCE at startup, inlined as base64 in receipts
// so the browser never makes a network request when printing.
// ---------------------------------------------------------------------------
String? _cachedLogoBase64;

/// Call this once in main() after Firebase init to pre-load the receipt logo.
Future<void> preloadReceiptLogo() async {
  try {
    final ByteData data = await rootBundle.load('assets/receipt_logo.png');
    final Uint8List bytes = data.buffer.asUint8List();
    _cachedLogoBase64 = 'data:image/png;base64,${base64Encode(bytes)}';
  } catch (e) {
    debugPrint('preloadReceiptLogo: failed to cache logo — $e');
  }
}

// 1. CustomAppBar
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String userName;
  final String userRole;
  final VoidCallback onLogout;
  final VoidCallback? onProfilePressed;
  final bool isMockMode;
  final ValueChanged<bool>? onMockToggle;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.userName,
    required this.userRole,
    required this.onLogout,
    this.onProfilePressed,
    this.isMockMode = false,
    this.onMockToggle,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor = Colors.grey;
    if (userRole.toLowerCase() == "manager") {
      badgeColor = AppTheme.primaryColor;
    } else if (userRole.toLowerCase() == "cashier") {
      badgeColor = Colors.blue.shade700;
    } else if (userRole.toLowerCase() == "expediter") {
      badgeColor = Colors.green.shade700;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    return AppBar(
      title: Row(
        children: [
          Image.asset(
            'assets/logo.png',
            height: 35,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 35,
              width: 35,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant, color: AppTheme.primaryColor, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (!isNarrow) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white70, width: 1),
            ),
            child: Text(
              userRole.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        PopupMenuButton<String>(
          offset: const Offset(0, 50),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.secondaryColor,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              if (!isNarrow) ...[
                const SizedBox(width: 8),
                Text(
                  userName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ],
              const Icon(Icons.arrow_drop_down, color: Colors.white),
              const SizedBox(width: 12),
            ],
          ),
          onSelected: (val) {
            if (val == 'profile' && onProfilePressed != null) {
              onProfilePressed!();
            } else if (val == 'logout') {
              onLogout();
            }
          },
          itemBuilder: (context) => [
            if (onProfilePressed != null)
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: AppTheme.textColor),
                    SizedBox(width: 8),
                    Text('My Profile'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// 2. CustomButton
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final bool isOutlined;
  final IconData? icon;
  final String size; // 'small', 'medium', 'large'

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.isOutlined = false,
    this.icon,
    this.size = 'medium',
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? AppTheme.primaryColor;
    double verticalPadding = 14;
    double horizontalPadding = 24;
    double fontSize = 16;

    if (size == 'small') {
      verticalPadding = 8;
      horizontalPadding = 16;
      fontSize = 13;
    } else if (size == 'large') {
      verticalPadding = 18;
      horizontalPadding = 32;
      fontSize = 18;
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: isOutlined ? Colors.transparent : themeColor,
      foregroundColor: isOutlined ? themeColor : Colors.white,
      shadowColor: isOutlined ? Colors.transparent : null,
      side: isOutlined ? BorderSide(color: themeColor, width: 1.5) : null,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    final childWidget = isLoading
        ? SizedBox(
            height: fontSize + 2,
            width: fontSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(isOutlined ? themeColor : Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 2),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
              ),
            ],
          );

    return isOutlined
        ? OutlinedButton(
            style: buttonStyle,
            onPressed: isLoading ? null : onPressed,
            child: childWidget,
          )
        : ElevatedButton(
            style: buttonStyle,
            onPressed: isLoading ? null : onPressed,
            child: childWidget,
          );
  }
}

// 3. CustomTextField
class CustomTextField extends StatefulWidget {
  final String label;
  final String? placeholder;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool isPassword;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  const CustomTextField({
    super.key,
    required this.label,
    this.placeholder,
    required this.controller,
    this.validator,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor, fontSize: 14),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          obscureText: widget.isPassword ? _obscureText : false,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          style: const TextStyle(fontSize: 15, color: AppTheme.textColor),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, color: Colors.grey) : null,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

// 4. LoadingWidget
class LoadingWidget extends StatelessWidget {
  final String message;

  const LoadingWidget({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
          )
        ],
      ),
    );
  }
}

// 5. EmptyStateWidget
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: .center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              if (actionLabel != null && onActionPressed != null) ...[
                const SizedBox(height: 20),
                CustomButton(
                  text: actionLabel!,
                  onPressed: onActionPressed,
                  size: 'small',
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// 6. ErrorWidget
class CustomErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const CustomErrorWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final bool isNetworkError = message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('internet') ||
        message.toLowerCase().contains('connection') ||
        message.toLowerCase().contains('socketexception') ||
        message.toLowerCase().contains('unavailable') ||
        message.toLowerCase().contains('failed host lookup');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNetworkError ? Icons.wifi_off : Icons.error_outline,
              color: isNetworkError ? Colors.orange : AppTheme.errorColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              isNetworkError ? "No Internet Connection" : "Something Went Wrong",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
            ),
            const SizedBox(height: 8),
            Text(
              isNetworkError ? "Please check your connection and try again." : message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              CustomButton(
                text: "Retry",
                onPressed: onRetry,
                size: 'small',
                icon: Icons.refresh,
              )
            ]
          ],
        ),
      ),
    );
  }
}

// 7. ConfirmationDialog
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDanger;
  final String? inputLabel;
  final String? inputPlaceholder;
  final TextEditingController? inputController;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDanger = false,
    this.inputLabel,
    this.inputPlaceholder,
    this.inputController,
  });

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isDanger ? Icons.warning_amber_rounded : Icons.info_outline,
            color: isDanger ? AppTheme.errorColor : AppTheme.secondaryColor,
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 14)),
            if (inputLabel != null && inputController != null) ...[
              const SizedBox(height: 16),
              CustomTextField(
                label: inputLabel!,
                placeholder: inputPlaceholder,
                controller: inputController!,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                },
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel, style: const TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDanger ? AppTheme.errorColor : AppTheme.primaryColor,
          ),
          onPressed: () {
            if (inputLabel != null && inputController != null) {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            } else {
              Navigator.of(context).pop(true);
            }
          },
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

// 8. StatusBadge
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        break;
      case 'in preparation':
        color = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        break;
      case 'ready':
        color = Colors.green.shade50;
        textColor = Colors.green.shade800;
        break;
      case 'completed':
        color = Colors.blue.shade50;
        textColor = Colors.blue.shade800;
        break;
      case 'cancelled':
        color = Colors.red.shade50;
        textColor = Colors.red.shade800;
        break;
      default:
        color = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.2), width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

// 9. DataTableWidget
class DataTableWidget extends StatelessWidget {
  final List<String> columns;
  final List<DataRow> rows;
  final String title;
  final Widget? actionWidget;

  const DataTableWidget({
    super.key,
    required this.columns,
    required this.rows,
    required this.title,
    this.actionWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                ),
                if (actionWidget != null) actionWidget!,
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: columns
                        .map((c) => DataColumn(
                              label: Text(
                                c,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor),
                              ),
                            ))
                        .toList(),
                    rows: rows,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 10. ImagePickerWidget
class ImagePickerWidget extends StatefulWidget {
  final String? initialBase64;
  final Function(String base64) onImageSelected;
  final String label;

  const ImagePickerWidget({
    super.key,
    this.initialBase64,
    required this.onImageSelected,
    this.label = 'Choose Image',
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _CustomImageCompressor {
  // Compress image URL to fit free-tier base64 limits (< 500KB)
  static void compressAndConvertWeb(html.File file, Function(String base64) onCompressed) {
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.listen((event) {
      final dataUrl = reader.result as String;
      // Let's draw to canvas to resize if size > 400KB
      if (file.size > 400000) {
        final img = html.ImageElement();
        img.src = dataUrl;
        img.onLoad.listen((_) {
          final canvas = html.CanvasElement();
          int width = img.width ?? 300;
          int height = img.height ?? 300;
          // Constrain max dimensions to 400px to guarantee < 100KB size
          double ratio = 1.0;
          if (width > 400 || height > 400) {
            ratio = 400 / (width > height ? width : height);
          }
          canvas.width = (width * ratio).toInt();
          canvas.height = (height * ratio).toInt();

          final ctx = canvas.context2D;
          ctx.drawImageScaled(img, 0, 0, canvas.width!, canvas.height!);
          final compressedDataUrl = canvas.toDataUrl('image/jpeg', 0.7); // 70% quality JPG
          onCompressed(compressedDataUrl);
        });
      } else {
        onCompressed(dataUrl);
      }
    });
  }
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  String? _base64String;

  @override
  void initState() {
    super.initState();
    _base64String = widget.initialBase64;
  }

  void _pickImage() {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        _CustomImageCompressor.compressAndConvertWeb(files[0], (base64) {
          setState(() {
            _base64String = base64;
          });
          widget.onImageSelected(base64);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_base64String != null && _base64String!.isNotEmpty) {
      try {
        final rawBase64 = _base64String!.contains(',')
            ? _base64String!.split(',')[1]
            : _base64String!;
        imageProvider = MemoryImage(base64Decode(rawBase64));
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Image Attachment",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageProvider != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(image: imageProvider, fit: BoxFit.cover),
                    )
                  : Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 36),
            ),
            CustomButton(
              text: widget.label,
              onPressed: _pickImage,
              size: 'small',
              icon: Icons.upload_file,
              isOutlined: true,
            ),
            if (_base64String != null && _base64String!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _base64String = null;
                  });
                  widget.onImageSelected('');
                },
              )
          ],
        ),
      ],
    );
  }
}

// 11. SearchBarWidget
class SearchBarWidget extends StatefulWidget {
  final String placeholder;
  final ValueChanged<String> onChanged;

  const SearchBarWidget({
    super.key,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChange(String text) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onTextChange,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              )
            : null,
      ),
    );
  }
}

// 12. SummaryCard
class SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color? iconColor;

  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: iconColor ?? color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Global Browser Utilities for Printing & Beep alert

void triggerWebPrint(BuildContext context, OrderModel order) {
  try {
    // Use the cached inline base64 logo so no image fetch is needed at print time
    final logoSrc = _cachedLogoBase64 ?? 'assets/receipt_logo.png';
    final orderTokenId = order.tokenId ?? 'N/A';
    final orderId = order.orderId;
    final orderStatus = "${order.status.toUpperCase()} / ${order.isPaid ? 'PAID' : 'UNPAID'}";
    final orderDate = DateFormat('dd/MM/yy').format(order.createdAt.toLocal());
    final orderTime = DateFormat('hh:mm a').format(order.createdAt.toLocal());
    final printedDateTime = DateFormat('dd/MM/yy hh:mm a').format(DateTime.now());
    final cashierName = order.cashierName;
    final orderTaker = order.orderTaker ?? 'Customer';
    String riderHtml = '';
    if (order.orderType.toLowerCase() == 'delivery' && order.riderName != null && order.riderName!.trim().isNotEmpty) {
      riderHtml = '<div style="margin-top: 3px;">Rider: ${order.riderName}</div>';
    }
    
    final orderType = order.orderType.toUpperCase();
    final customerName = order.customerName.trim().isEmpty ? 'N/A' : order.customerName;
    
    String tableNumberHtml = '';
    if (order.orderType.toLowerCase() == 'dine-in') {
      final tableNumber = (order.tableNumber == null || order.tableNumber!.trim().isEmpty) ? 'N/A' : order.tableNumber!;
      tableNumberHtml = '<div>Table: $tableNumber</div>';
    }
    
    String phoneHtml = '';
    if (order.orderType.toLowerCase() == 'takeaway' || order.orderType.toLowerCase() == 'delivery') {
      final phone = (order.customerPhone == null || order.customerPhone!.trim().isEmpty) ? 'N/A' : order.customerPhone!;
      phoneHtml = '<div>Phone: $phone</div>';
    }
    
    String addressHtml = '';
    if (order.orderType.toLowerCase() == 'delivery') {
      final address = (order.deliveryAddress == null || order.deliveryAddress!.trim().isEmpty) ? 'N/A' : order.deliveryAddress!;
      addressHtml = '<div>Address: $address</div>';
    }

    // Build items table rows
    final rowsBuf = StringBuffer();
    for (var item in order.items) {
      rowsBuf.write('''
        <tr>
          <td style="padding: 4px 0; vertical-align: top;">
            ${item.name}
          </td>
          <td style="text-align: center; padding: 4px 0; vertical-align: top;">${item.quantity}</td>
          <td style="text-align: right; padding: 4px 0; vertical-align: top;">${item.unitPrice.toStringAsFixed(0)}</td>
          <td style="text-align: right; padding: 4px 0; vertical-align: top;">${item.totalPrice.toStringAsFixed(0)}</td>
        </tr>
      ''');
    }
    for (var d in order.deals) {
      final dPrice = double.tryParse(d['price']?.toString() ?? '0') ?? 0.0;
      rowsBuf.write('''
        <tr>
          <td style="padding: 4px 0; vertical-align: top;">Bundle: ${d['name']}</td>
          <td style="text-align: center; padding: 4px 0; vertical-align: top;">1</td>
          <td style="text-align: right; padding: 4px 0; vertical-align: top;">${dPrice.toStringAsFixed(0)}</td>
          <td style="text-align: right; padding: 4px 0; vertical-align: top;">${dPrice.toStringAsFixed(0)}</td>
        </tr>
      ''');
    }

    final deliveryChargesHtml = order.orderType == "delivery"
        ? '''
        <tr>
          <td style="padding: 2px 0;">Delivery Charges</td>
          <td style="text-align: right; padding: 2px 0;">Rs. ${order.deliveryCharges.toStringAsFixed(2)}</td>
        </tr>
        '''
        : '';

    // Build HTML content string
    String receiptHtml;
     final discountHtml = order.discountAmount > 0
        ? '''<tr>
               <td style="padding: 2px 0;">Discount</td>
               <td style="text-align: right; padding: 2px 0;">-Rs. ${order.discountAmount.toStringAsFixed(2)}</td>
             </tr>'''
        : '';

    final taxHtml = order.tax > 0
        ? '''<tr>
               <td style="padding: 2px 0;">Tax</td>
               <td style="text-align: right; padding: 2px 0;">Rs. ${order.tax.toStringAsFixed(2)}</td>
             </tr>'''
        : '';

    final double cashVal = order.isPaid ? (order.amountReceived > 0 ? order.amountReceived : order.grandTotal) : 0.0;
    final double changeVal = order.isPaid ? order.change : 0.0;

    final cashChangeHtml = order.isPaid
        ? '''
          <table style="width: 100%; font-size: 9pt;">
            <tr>
              <td style="padding: 2px 0;">Cash</td>
              <td style="text-align: right; padding: 2px 0;">Rs. ${cashVal.toStringAsFixed(2)}</td>
            </tr>
            <tr style="font-weight: bold;">
              <td style="padding: 2px 0;">Change</td>
              <td style="text-align: right; padding: 2px 0;">Rs. ${changeVal.toStringAsFixed(2)}</td>
            </tr>
          </table>
          '''
        : '';

    receiptHtml = '''
      <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>PRINT RECEIPT</title>
          <style>
            * {
              box-sizing: border-box;
              word-wrap: break-word;
              overflow-wrap: break-word;
            }
            @page {
              size: 80mm auto;
              margin: 3mm 8mm;
            }
            html, body {
              width: 100%;
              margin: 0;
              padding: 0;
            }
            body {
              font-family: 'Times New Roman', Times, serif;
              font-size: 9.5pt;
              line-height: 1.4;
              color: #000;
            }
            @media print {
              html, body {
                width: 100%;
                margin: 0;
                padding: 0;
              }
            }
            .center { text-align: center; }
            .bold { font-weight: bold; }
            .divider {
              border-top: 1px solid #000;
              margin: 1.5mm 0;
              width: 100%;
            }
            .header-logo {
              width: 50mm;
              height: auto;
              display: block;
              margin: 0 auto 2mm auto;
            }
            table {
              width: 100%;
              border-collapse: collapse;
              table-layout: fixed;
            }
            td, th {
              word-wrap: break-word;
              overflow-wrap: break-word;
            }
          </style>
        </head>
         <body>
           <img class="header-logo" src="$logoSrc" alt="Logo">
           
           <div class="center" style="font-size: 7.5pt; margin-top: 2px;">1/4-L Chak Road Near Hassan Block Okara</div>
           <div class="center" style="font-size: 7.5pt;">0321-8086322 / 0318-6941313</div>
           <div class="center bold" style="font-size: 9pt; margin: 4px 0; padding: 2px 0; border: 1px solid #000; text-transform: uppercase;">
             $orderStatus
           </div>
                      
           <div style="display: flex; justify-content: space-between; font-size: 9pt;">
             <span>Token-ID# $orderTokenId</span>
             <span>Order-ID: $orderId</span>
           </div>
           
           <div class="divider"></div>
           
           <div style="font-size: 9pt;">
             <div style="display: flex; justify-content: space-between;">
               <span>Date: $orderDate</span>
               <span>Time: $orderTime</span>
             </div>
             <div style="margin-top: 2px;">Cashier: $cashierName</div>
             <div style="margin-top: 2px;">Order Taker: $orderTaker</div>
             $riderHtml
           </div>
           
           <div class="divider"></div>
           
           <div class="center bold" style="font-size: 9pt; letter-spacing: 0.5px;">Customer Details</div>
           
           <div class="divider"></div>
           
           <div style="line-height: 1.4; font-size: 9pt;">
             <div>Type: $orderType</div>
             <div>Customer: $customerName</div>
             $tableNumberHtml
             $phoneHtml
             $addressHtml
           </div>
           
           <div class="divider"></div>
           
           <div class="center bold" style="font-size: 9pt; letter-spacing: 0.5px;">Order Details</div>
           
           <div class="divider"></div>
           
           <table style="width: 100%; border-collapse: collapse; line-height: 1.3;">
             <thead>
               <tr style="border-bottom: 1px solid #000; font-weight: bold;">
                 <th style="text-align: left; padding: 4px 0; width: 45%;">Item</th>
                 <th style="text-align: center; padding: 4px 0; width: 15%;">Qty</th>
                 <th style="text-align: right; padding: 4px 0; width: 20%;">Rate</th>
                 <th style="text-align: right; padding: 4px 0; width: 20%;">Total</th>
               </tr>
             </thead>
             <tbody>
               ${rowsBuf.toString()}
             </tbody>
           </table>
           
           <div class="divider"></div>
           
           <table style="width: 100%; font-size: 9pt;">
             <tr>
               <td style="padding: 2px 0;">Sub Total</td>
               <td style="text-align: right; padding: 2px 0;">Rs. ${order.subtotal.toStringAsFixed(2)}</td>
             </tr>
             $discountHtml
             $taxHtml
             $deliveryChargesHtml
             <tr style="font-weight: bold; font-size: 11pt; border-top: 1px solid #000; border-bottom: 1px solid #000;">
               <td style="padding: 4px 0;">GRAND TOTAL</td>
               <td style="text-align: right; padding: 4px 0;">Rs. ${order.grandTotal.toStringAsFixed(2)}</td>
             </tr>
           </table>
           $cashChangeHtml
           <div class="divider"></div>
           <div class="center" style="font-size: 9pt; margin-top: 6px; font-weight: bold;">Thank You!</div>
           <div class="center" style="font-size: 9pt; font-weight: bold;">Please Visit Again</div>
          
          <div class="divider"></div>
          <div class="center" style="font-size: 7.5pt; margin-top: 2px;">Printed Date/Time: $printedDateTime</div>
          <div class="divider"></div>
          
          <div class="center bold" style="font-size: 7.5pt; margin-top: 2px;">POS System Developed By</div>
          <div class="center" style="font-size: 7.5pt; font-weight: bold;">Voryent Solutions  0329 7600120</div>
          
          <script>
            setTimeout(function() {
              window.focus();
              window.print();
            }, 50);
          </script>
        </body>
      </html>
    ''';

    final iframe = html.IFrameElement();
    
    // Style the iframe to be hidden off-screen (leaving visible to print engine)
    iframe.style
      ..position = 'absolute'
      ..left = '-9999px'
      ..width = '400px'
      ..height = '1600px'
      ..border = 'none';
      
    html.document.body?.append(iframe);
    
    iframe.srcdoc = receiptHtml;
    
    // Cleanup temporary iframe after print interaction
    Timer(const Duration(seconds: 30), () {
      iframe.remove();
    });
  } catch (e, stack) {
    debugPrint("triggerWebPrint error: $e\n$stack");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Print triggering failed: $e"), backgroundColor: Colors.red),
    );
  }
}

void triggerClosingPrint(BuildContext context, DailyClosingModel closing) {
  try {
    final logoSrc = _cachedLogoBase64 ?? 'assets/receipt_logo.png';
    final printedDateTime = DateFormat('dd/MM/yy hh:mm a').format(DateTime.now());

    final closingHtml = '''
      <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>PRINT DAILY CLOSING</title>
          <style>
            * {
              box-sizing: border-box;
              word-wrap: break-word;
              overflow-wrap: break-word;
            }
            @page {
              size: 80mm auto;
              margin: 3mm 8mm;
            }
            html, body {
              width: 100%;
              margin: 0;
              padding: 0;
            }
            body {
              font-family: 'Times New Roman', Times, serif;
              font-size: 9.5pt;
              line-height: 1.4;
              color: #000;
            }
            @media print {
              html, body {
                width: 100%;
                margin: 0;
                padding: 0;
              }
            }
            .center { text-align: center; }
            .bold { font-weight: bold; }
            .divider {
              border-top: 1px solid #000;
              margin: 1.5mm 0;
              width: 100%;
            }
            .header-logo {
              width: 22mm;
              height: auto;
              display: block;
              margin: 0 auto 2mm auto;
            }
            table {
              width: 100%;
              border-collapse: collapse;
              table-layout: fixed;
            }
            td, th {
              word-wrap: break-word;
              overflow-wrap: break-word;
            }
          </style>
        </head>
         <body>
           <img class="header-logo" src="$logoSrc" alt="Logo">
           
           <div class="center" style="font-size: 7.5pt; margin-top: 2px;">1/4-L Chak Road Near Hassan Block Okara</div>
           <div class="center" style="font-size: 7.5pt;">0321-8086322 / 0318-6941313</div>
           <div class="center bold" style="font-size: 9pt; margin: 4px 0; padding: 2px 0; border: 1px solid #000;">
             DAILY CLOSING SUMMARY
           </div>
           
           <div class="divider"></div>
           
           <div style="font-size: 9pt;">
             <div>Logical Date: ${closing.id}</div>
             <div style="margin-top: 2px;">Closed By: ${closing.closedByName}</div>
             <div style="margin-top: 2px;">Printed Date/Time: $printedDateTime</div>
           </div>
           
           <div class="divider"></div>
           
           <table style="width: 100%; font-size: 9pt;">
             <tr>
               <td style="padding: 2px 0;">Total Punch Orders</td>
               <td style="text-align: right; padding: 2px 0; font-weight: bold;">${closing.totalPunchOrders}</td>
             </tr>
             <tr>
               <td style="padding: 2px 0;">Total Confirmed Orders</td>
               <td style="text-align: right; padding: 2px 0; font-weight: bold;">${closing.totalConfirmedOrders}</td>
             </tr>
             <tr>
               <td style="padding: 2px 0;">Cancelled Orders</td>
               <td style="text-align: right; padding: 2px 0; font-weight: bold;">${closing.cancelledOrders}</td>
             </tr>
             <tr style="font-weight: bold; border-top: 1px dashed #000;">
               <td style="padding: 4px 0;">Total Today Revenue</td>
               <td style="text-align: right; padding: 4px 0;">Rs. ${closing.totalTodayRevenue.toStringAsFixed(2)}</td>
             </tr>
           </table>
           <div class="divider"></div>
           
           <table style="width: 100%; font-size: 9pt;">
             <tr>
               <td style="padding: 2px 0;">Total Cash</td>
               <td style="text-align: right; padding: 2px 0; font-weight: bold;">Rs. ${closing.cashAmount.toStringAsFixed(2)}</td>
             </tr>
             <tr>
               <td style="padding: 2px 0;">Online Payment</td>
               <td style="text-align: right; padding: 2px 0; font-weight: bold;">Rs. ${closing.onlineAmount.toStringAsFixed(2)}</td>
             </tr>
             <tr>
               <td style="padding: 2px 0;">Today Expense</td>
               <td style="text-align: right; padding: 2px 0; font-weight: bold; color: red;">Rs. ${closing.cardAmount.toStringAsFixed(2)}</td>
             </tr>
             <tr style="font-weight: bold; border-top: 1px dashed #000;">
               <td style="padding: 4px 0;">Total Received (Cash + Online)</td>
               <td style="text-align: right; padding: 4px 0;">Rs. ${(closing.cashAmount + closing.onlineAmount).toStringAsFixed(2)}</td>
             </tr>
             <tr style="font-weight: bold; border-top: 1px solid #000;">
               <td style="padding: 4px 0;">Net Balance</td>
               <td style="text-align: right; padding: 4px 0;">Rs. ${(closing.cashAmount + closing.onlineAmount - closing.cardAmount).toStringAsFixed(2)}</td>
             </tr>
           </table>
           
           <div class="divider"></div>
           
           <div class="center bold" style="font-size: 7.5pt; margin-top: 2px;">POS System Developed By</div>
           <div class="center" style="font-size: 7.5pt; font-weight: bold;">Voryent Solution  0329 7600120</div>
           
           <script>
             setTimeout(function() {
               window.focus();
               window.print();
             }, 50);
           </script>
         </body>
       </html>
    ''';

    final iframe = html.IFrameElement()
      ..style.position = 'absolute'
      ..style.left = '-9999px'
      ..style.width = '400px'
      ..style.height = '1600px'
      ..style.border = 'none';
      
    html.document.body?.append(iframe);
    
    iframe.srcdoc = closingHtml;
    
    Timer(const Duration(seconds: 30), () {
      iframe.remove();
    });
  } catch (e, stack) {
    debugPrint("triggerClosingPrint error: $e\n$stack");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Print triggering failed: $e"), backgroundColor: Colors.red),
    );
  }
}

void triggerBeepNotification() {
  try {
    final audio = html.AudioElement(
      "data:audio/wav;base64,//uQRAAAAWMSLwUIYAAsYkXgoQwAEaYLWfkWgAI0wWs/ItAAAGDgYtAgAyN+QWaAAihwMWm4G8QQRDiMcCBcH3Cc+CDv/7xA4Tvh9Rz/y8QADBwMWgQAZG/ILNAARQ4GLTcDeIIIhxGOBAuD7hOfBB3/94gcJ3w+o5/5eIAIAAAVwWgQAVQ2ORaIQwEMAJiDg95G4nQL7mQVWI6GwRcfsZAcsKkJvxgxEjzFUgfHoSQ9Qq7KNwqHwuB13MA4a1q/DmBrHgPcmjiGoh//EwC5nGPEmS4RcfkVKOhJf+WOgoxJclFz3kgn//dBA+ya1GhurNn8zb//9NNutNuhz31f////9vt///z+IdAEAAAK4LQIAKobHItEIYCGAExBwe8jcToF9zIKrEdDYIuP2MgOWFSE34wYiR5iqQPj0JIeoVdlG4VD4XA67mAcNa1fhzA1jwHuTRxDUQ//iYBczjHiTJcIuPyKlHQkv/LHQUYkuSi57yQT//uggfZNajQ3Vmz+Zt//+mm3Wm3Q576v//"
    );
    audio.play();
  } catch (e) {
    debugPrint("Browser Audio Error playing beep: $e");
  }
}

class ReceiptPreviewWidget extends StatelessWidget {
  final OrderModel order;
  const ReceiptPreviewWidget({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final orderTokenId = order.tokenId ?? 'N/A';
    final orderId = order.orderId;
    final orderStatus = order.status;
    final orderDate = DateFormat('dd/MM/yyyy').format(order.createdAt);
    final orderTime = DateFormat('hh:mm a').format(order.createdAt);
    final cashierName = order.cashierName;
    final orderType = order.orderType.toUpperCase();
    final customerName = order.customerName.trim().isEmpty ? 'N/A' : order.customerName;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Logo
          Image.asset(
            'assets/receipt_logo.png',
            height: 80,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          // Sub-header details
          const Text(
            "1/4-L Chak Road Near Hassan Block Okara",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black),
          ),
          const Text(
            "0321-8086322 / 0318-6941313",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black),
          ),
          const SizedBox(height: 8),
          // Status Box
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Text(
              "${orderStatus.toUpperCase()} / ${order.isPaid ? 'PAID' : 'UNPAID'}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.black, thickness: 1),
          // Token & Order ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Token-ID# $orderTokenId", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
              Text("Order-ID: $orderId", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
            ],
          ),
          const Divider(color: Colors.black, thickness: 1),
          // Date & Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Date: $orderDate", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
              Text("Time: $orderTime", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 4),
          Text("Cashier: $cashierName", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
          const SizedBox(height: 2),
          Text("Order Taker: ${order.orderTaker ?? 'Customer'}", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
          if (order.orderType.toLowerCase() == 'delivery' && order.riderName != null && order.riderName!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text("Rider: ${order.riderName}", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
          ],
          const Divider(color: Colors.black, thickness: 1),
          // Customer Detail Header
          const Text(
            "Customer Details",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Times New Roman', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const Divider(color: Colors.black, thickness: 1),
          // Customer details body
          Text("Type: $orderType", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
          Text("Customer: $customerName", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
          if (order.orderType.toLowerCase() == 'dine-in')
            Text("Table: ${order.tableNumber ?? 'N/A'}", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
          if (order.orderType.toLowerCase() == 'takeaway' || order.orderType.toLowerCase() == 'delivery')
            Text("Phone: ${order.customerPhone ?? 'N/A'}", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
          if (order.orderType.toLowerCase() == 'delivery')
            Text("Address: ${order.deliveryAddress ?? 'N/A'}", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
          const Divider(color: Colors.black, thickness: 1),
          // Order Detail Header
          const Text(
            "Order Details",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Times New Roman', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const Divider(color: Colors.black, thickness: 1),
          // Order Items Table
          Table(
            columnWidths: const {
              0: FlexColumnWidth(4),
              1: FixedColumnWidth(30),
              2: FixedColumnWidth(55),
              3: FixedColumnWidth(55),
            },
            children: [
              // Header
              const TableRow(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1))),
                children: [
                  Padding(padding: EdgeInsets.symmetric(vertical: 4.0), child: Text("Item", style: TextStyle(fontFamily: 'Times New Roman', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 4.0), child: Text("Qty", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Times New Roman', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 4.0), child: Text("Rate", textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Times New Roman', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 4.0), child: Text("Total", textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Times New Roman', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black))),
                ],
              ),
              ...order.items.map((item) => TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(item.name, style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Text("${item.quantity}", textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Text("${item.unitPrice.toStringAsFixed(0)}", textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Text("${item.totalPrice.toStringAsFixed(0)}", textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black))),
                ],
              )),
              ...order.deals.map((deal) {
                final dPrice = double.tryParse(deal['price']?.toString() ?? '0') ?? 0.0;
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text("Bundle: ${deal['name']}", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 4.0), child: Text("1", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black))),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Text(dPrice.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black))),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Text(dPrice.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black))),
                  ],
                );
              }),
            ],
          ),
          const Divider(color: Colors.black, thickness: 1),
          // Subtotal, Discount, Tax, Grand Total
          _buildBillRow("Sub Total", "Rs. ${order.subtotal.toStringAsFixed(2)}"),
          _buildBillRow("Discount", "-Rs. ${order.discountAmount.toStringAsFixed(2)}"),
          _buildBillRow("Tax", "Rs. ${order.tax.toStringAsFixed(2)}"),
          if (order.orderType == "delivery")
            _buildBillRow("Delivery Charges", "Rs. ${order.deliveryCharges.toStringAsFixed(2)}"),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black, width: 1),
                bottom: BorderSide(color: Colors.black, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("GRAND TOTAL", style: TextStyle(fontFamily: 'Times New Roman', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                Text("Rs. ${order.grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            ),
          ),
          const Text("Thank You!", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Times New Roman', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
          const Text("Please Visit Again", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Times New Roman', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
          const Divider(color: Colors.black, thickness: 1),
          const SizedBox(height: 4),
          const Text("POS System Developed By", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Times New Roman', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
          const Text("Voryent Solutions  0329 7600120", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Times New Roman', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    ),);
  }

  Widget _buildBillRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
          Text(value, style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 11, color: Colors.black)),
        ],
      ),
    );
  }
}
