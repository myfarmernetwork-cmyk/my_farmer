import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late String _role;
  late String _productionType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name']);
    _addressController = TextEditingController(text: widget.userData['address']);
    _phoneController = TextEditingController(text: widget.userData['phone']);
    _role = widget.userData['role'] ?? 'buyer';
    _productionType = widget.userData['productionType'] ?? 'Konvencionalna';
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
      'name': _nameController.text,
      'address': _addressController.text,
      'phone': _phoneController.text,
      'role': _role,
      'productionType': _productionType,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Uredi podatke")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Izbor uloge iz biznis plana
            const Text("Koja je Vaša uloga?", style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile(
              title: const Text("Kupac"),
              value: 'buyer',
              groupValue: _role,
              onChanged: (val) => setState(() => _role = val.toString()),
            ),
            RadioListTile(
              title: const Text("Prodavac (Farmer)"),
              value: 'seller',
              groupValue: _role,
              onChanged: (val) => setState(() => _role = val.toString()),
            ),

            const Divider(),

            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Ime i prezime")),
            TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: "Adresa stanovanja")),
            TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: "Broj telefona")),

            if (_role == 'seller') ...[
              const SizedBox(height: 20),
              const Text("Detalji o proizvodnji", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField(
                value: _productionType,
                items: ['Organska', 'Konvencionalna'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (val) => setState(() => _productionType = val.toString()),
                decoration: const InputDecoration(labelText: "Način proizvodnje"),
              ),
            ],

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              child: const Text("SAČUVAJ IZMJENE"),
            ),
          ],
        ),
      ),
    );
  }
}