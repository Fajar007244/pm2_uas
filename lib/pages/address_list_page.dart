import 'package:flutter/material.dart';
import 'add_address_page.dart';
import '../services/address_service.dart';
import '../services/auth_service.dart';

class AddressListPage extends StatefulWidget {
  final bool selectMode;

  const AddressListPage({Key? key, this.selectMode = false}) : super(key: key);

  @override
  _AddressListPageState createState() => _AddressListPageState();
}

class _AddressListPageState extends State<AddressListPage> {
  final AddressService _addressService = AddressService();
  final AuthService _authService = AuthService();
  
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Anda harus login terlebih dahulu')),
        );
        return;
      }

      final addresses = await _addressService.getUserAddresses(currentUser.id);
      setState(() {
        _addresses = addresses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat alamat: $e')),
      );
    }
  }

  void _setDefaultAddress(String addressId) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) {
        print('No current user found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Anda harus login terlebih dahulu')),
        );
        return;
      }

      print('Setting default address: $addressId for user: ${currentUser.id}');

      // First, update all addresses to not be default
      for (var address in _addresses) {
        print('Updating address ${address['id']} to non-default');
        await _addressService.updateAddress(
          addressId: address['id'], 
          userId: currentUser.id, 
          isDefault: false
        );
      }

      // Then set the selected address as default
      print('Setting address $addressId as default');
      await _addressService.updateAddress(
        addressId: addressId, 
        userId: currentUser.id, 
        isDefault: true
      );

      // Refresh the list
      await _fetchAddresses();

      print('Default address set successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alamat utama berhasil diperbarui')),
      );
    } catch (e) {
      print('Error setting default address: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengatur alamat utama: $e')),
      );
    }
  }

  void _deleteAddress(String addressId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Hapus Alamat'),
          content: Text('Apakah Anda yakin ingin menghapus alamat ini?'),
          actions: [
            TextButton(
              child: Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Hapus'),
              onPressed: () async {
                try {
                  final currentUser = _authService.getCurrentUser();
                  if (currentUser == null) return;

                  await _addressService.deleteAddress(
                    addressId: addressId, 
                    userId: currentUser.id
                  );

                  // Refresh the list
                  await _fetchAddresses();

                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus alamat: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _editAddress(Map<String, dynamic> address) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAddressPage(existingAddress: address),
      ),
    );

    // If the address was updated, refresh the list
    if (result == true) {
      await _fetchAddresses();
    }
  }

  void _showAddressDetails(Map<String, dynamic> address) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Detail Alamat',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text('Label: ${address['label']}'),
              Text('Penerima: ${address['recipient']}'),
              Text('Telepon: ${address['phone']}'),
              Text('Alamat: ${address['address']}'),
            ],
          ),
        );
      },
    );
  }

  void _showAddressOptions(Map<String, dynamic> address) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit Alamat'),
              onTap: () {
                Navigator.pop(context);
                _editAddress(address);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Hapus Alamat', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteAddress(address['id']);
              },
            ),
            ListTile(
              leading: Icon(Icons.star, color: Colors.orange),
              title: Text('Jadikan Alamat Utama'),
              onTap: () {
                Navigator.pop(context);
                _setDefaultAddress(address['id']);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode 
          ? 'Pilih Alamat' 
          : 'Daftar Alamat'),
        actions: [
          if (!widget.selectMode)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddAddressPage(),
                  ),
                );

                // If the address was added, refresh the list
                if (result == true) {
                  await _fetchAddresses();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Belum ada alamat tersimpan',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddAddressPage(),
                            ),
                          );

                          // If the address was added, refresh the list
                          if (result == true) {
                            await _fetchAddresses();
                          }
                        },
                        child: Text('Tambah Alamat'),
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final address = _addresses[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ListTile(
                        title: Text(
                          address['label'] ?? 'Alamat',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(address['recipient'] ?? ''),
                            Text(address['phone'] ?? ''),
                            Text(address['address'] ?? ''),
                          ],
                        ),
                        trailing: address['is_default'] 
                          ? Icon(Icons.check_circle, color: Colors.green)
                          : null,
                        onTap: widget.selectMode
                          ? () => Navigator.of(context).pop(address)
                          : () => _showAddressDetails(address),
                        onLongPress: !widget.selectMode 
                          ? () => _showAddressOptions(address)
                          : null,
                      ),
                    );
                  },
                ),
    );
  }
}
