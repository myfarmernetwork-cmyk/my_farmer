import 'package:flutter/material.dart';
import 'add_product_screen.dart'; // Import za tvoj ekran za dodavanje proizvoda
import '../farmer/farmer_chat_list_screen.dart'; // Import za poruke koje smo uradili
import '../admin/admin_orders_screen.dart';
import 'my_products_screen.dart';
class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Moj Farmer Panel"),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Gornji dio sa dobrodošlicom
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green[700],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.green, size: 40)),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Dobrodošli nazad,", style: TextStyle(color: Colors.white70)),
                    Text("Farmer Siniša", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          // GRID SA OPCIJAMA (Dashboard)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  // 1. PORUKE
                  _buildMenuCard(
                      context,
                      "Poruke",
                      Icons.chat_bubble_rounded,
                      Colors.blue,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FarmerChatListScreen()))
                  ),

                  // 2. DODAJ PROIZVOD
                  _buildMenuCard(
                      context,
                      "Novi Proizvod",
                      Icons.add_box_rounded,
                      Colors.green,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProductScreen()))
                  ),

                  // Pronađi Karticu 3 (Narudžbe) i zameni onPressed:
                  _buildMenuCard(
                      context,
                      "Narudžbe",
                      Icons.assignment_rounded,
                      Colors.orange,
                          () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AdminOrdersScreen())
                        );
                      }
                  ),

                    // Kartica 4
                    _buildMenuCard(
                        context,
                        "Moji Proizvodi",
                        Icons.inventory_2_rounded,
                        Colors.purple,
                            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyProductsScreen()))
                    ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Funkcija za dizajn kartica
  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 35),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}