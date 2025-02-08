import 'package:flutter/material.dart';
import '../services/address_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

class AddAddressPage extends StatefulWidget {
  final Map<String, dynamic>? existingAddress;

  const AddAddressPage({Key? key, this.existingAddress}) : super(key: key);

  @override
  _AddAddressPageState createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _addressController;
  late TextEditingController _recipientController;
  late TextEditingController _phoneController;

  bool _isDefault = false;
  bool _isLoading = false;

  final AddressService _addressService = AddressService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing address data if editing
    _labelController =
        TextEditingController(text: widget.existingAddress?['label'] ?? '');
    _addressController =
        TextEditingController(text: widget.existingAddress?['address'] ?? '');
    _recipientController =
        TextEditingController(text: widget.existingAddress?['recipient'] ?? '');
    _phoneController =
        TextEditingController(text: widget.existingAddress?['phone'] ?? '');

    // Set default status if editing an existing address
    _isDefault = widget.existingAddress?['isDefault'] ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _recipientController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Method to get current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final location = await LocationService.getCurrentLocation();
      
      if (location.isNotEmpty) {
        // Update only address field with full address
        _addressController.text = location['fullAddress'] ?? '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lokasi berhasil diambil')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil lokasi')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      try {
        final currentUser = _authService.getCurrentUser();
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Anda harus login terlebih dahulu')),
          );
          return;
        }

        if (widget.existingAddress == null) {
          // Adding new address
          await _addressService.addAddress(
            userId: currentUser.id,
            label: _labelController.text,
            address: _addressController.text,
            recipient: _recipientController.text,
            phone: _phoneController.text,
            isDefault: _isDefault,
          );
        } else {
          // Editing existing address
          await _addressService.updateAddress(
            addressId: widget.existingAddress!['id'],
            userId: currentUser.id,
            label: _labelController.text,
            address: _addressController.text,
            recipient: _recipientController.text,
            phone: _phoneController.text,
            isDefault: _isDefault,
          );
        }

        // Navigate back to previous screen
        Navigator.of(context).pop(true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan alamat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingAddress == null
            ? 'Tambah Alamat Baru'
            : 'Edit Alamat'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: 'Label Alamat (contoh: Rumah, Kantor)',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Label alamat tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Alamat Lengkap',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Alamat tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                ),
                IconButton(
                  icon: _isLoading 
                    ? CircularProgressIndicator() 
                    : Icon(Icons.my_location, color: Colors.blue),
                  onPressed: _isLoading ? null : _getCurrentLocation,
                  tooltip: 'Gunakan Lokasi Saat Ini',
                ),
              ],
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _recipientController,
              decoration: InputDecoration(
                labelText: 'Nama Penerima',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama penerima tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Nomor Telepon',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nomor telepon tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _isDefault,
                  onChanged: (bool? value) {
                    setState(() {
                      _isDefault = value ?? false;
                    });
                  },
                ),
                Text('Jadikan alamat utama'),
              ],
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveAddress,
              child: Text(widget.existingAddress == null
                  ? 'Simpan Alamat'
                  : 'Perbarui Alamat'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
