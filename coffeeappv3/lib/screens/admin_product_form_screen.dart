import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/categories.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';

// Challenge 5 — สร้าง/แก้ไขสินค้าผ่านฟอร์มเดียวกัน (product == null คือโหมดสร้างใหม่)
class AdminProductFormScreen extends StatefulWidget {
  final Product? product;

  const AdminProductFormScreen({super.key, this.product});

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _stockController;
  late final TextEditingController _priceController;
  late int _categoryId;

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(text: product?.description ?? '');
    // GET /api/products ไม่ได้ถูก parse เก็บ barcode ไว้ใน Product model (ไม่ใช้ในหน้า
    // Shopping) — ปล่อยว่างไว้ตอนแก้ไข ถ้าไม่กรอก backend จะใช้ค่าเดิมต่อ (ดู
    // backendapi.md: updateProduct fallback เป็น current.barcode)
    _barcodeController = TextEditingController();
    _stockController = TextEditingController(text: product?.stock.toString() ?? '');
    _priceController = TextEditingController(text: product?.price.toString() ?? '');
    _categoryId = product?.categoryId ?? ProductCategory.names.keys.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _pickedImage = picked;
      _pickedImageBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final provider = context.read<ProductProvider>();
    final token = auth.token;
    if (token == null) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final barcode = _barcodeController.text.trim();
    final stock = int.parse(_stockController.text.trim());
    final price = int.parse(_priceController.text.trim());

    final bool success;
    if (_isEditing) {
      success = await provider.updateProduct(
        token: token,
        id: widget.product!.id,
        name: name,
        description: description,
        barcode: barcode.isEmpty ? null : barcode,
        stock: stock,
        price: price,
        categoryId: _categoryId,
        imageFile: _pickedImage,
      );
    } else {
      success = await provider.createProduct(
        token: token,
        name: name,
        description: description,
        barcode: barcode,
        stock: stock,
        price: price,
        categoryId: _categoryId,
        imageFile: _pickedImage,
      );
    }

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.adminErrorMessage ?? 'Save failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<ProductProvider>().isSaving;
    final existingImageUrl = ApiConfig.imageUrl(widget.product?.image);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'New Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: AspectRatio(
                  aspectRatio: 1.5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildImagePreview(existingImageUrl),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_pickedImage == null ? 'Choose Image' : 'Change Image'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barcode',
                  border: const OutlineInputBorder(),
                  hintText: _isEditing ? '(leave blank to keep current)' : 'e.g. COFFEE015',
                ),
                validator: (value) {
                  if (_isEditing) return null;
                  return (value == null || value.trim().isEmpty) ? 'Required' : null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateNonNegativeInt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price (฿)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateNonNegativeInt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final entry in ProductCategory.names.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _categoryId = value);
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: isSaving ? null : _save,
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save Changes' : 'Create Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateNonNegativeInt(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 'Enter a valid number';
    return null;
  }

  Widget _buildImagePreview(String existingImageUrl) {
    if (_pickedImageBytes != null) {
      return Image.memory(_pickedImageBytes!, fit: BoxFit.cover);
    }
    if (existingImageUrl.isNotEmpty) {
      return Image.network(
        existingImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Center(
      child: Icon(
        Icons.add_photo_alternate_outlined,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}