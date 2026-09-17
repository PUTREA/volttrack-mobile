import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'login_screen.dart';
import 'monitoring_screen.dart';
import 'warranty_screen.dart';
import 'roi_screen.dart';
import 'profile_screen.dart';
import 'order_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  int _tab = 0;

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _MarketplaceTab(),
      const _OrdersTab(),
      const MonitoringScreen(),
      const WarrantyScreen(),
      const RoiScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('VoltTrack'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.store), label: 'Market'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Order'),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart),
            label: 'Monitor',
          ),
          NavigationDestination(icon: Icon(Icons.verified), label: 'Garansi'),
          NavigationDestination(icon: Icon(Icons.calculate), label: 'ROI'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _MarketplaceTab extends StatefulWidget {
  const _MarketplaceTab();

  @override
  State<_MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<_MarketplaceTab> {
  final _data = DataService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _data.products();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snap.data ?? [];
        if (products.isEmpty) {
          return const Center(child: Text('Belum ada produk.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final p = products[i];
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.solar_power,
                  color: Color(0xFF0F766E),
                ),
                title: Text('${p['product_name']}'),
                subtitle: Text('${p['model'] ?? '-'} · Stok ${p['stock_qty']}'),
                trailing: Text('Rp${p['price']}'),
              ),
            );
          },
        );
      },
    );
  }
}

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  final _data = DataService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _data.myOrders();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snap.data ?? [];
        if (orders.isEmpty) {
          return const Center(child: Text('Belum ada order.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final o = orders[i];
            final product = o['product'] as Map<String, dynamic>?;
            return Card(
              child: ListTile(
                title: Text(
                  'Order #${o['id']} · ${product?['product_name'] ?? '-'}',
                ),
                subtitle: Text('Qty ${o['quantity']} · ${o['payment_status']}'),
                trailing: Text('Rp${o['total_price']}'),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(order: o),
                    ),
                  );
                  if (mounted) setState(() => _future = _data.myOrders());
                },
              ),
            );
          },
        );
      },
    );
  }
}
