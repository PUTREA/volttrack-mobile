import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _data = DataService();
  final _fullName = TextEditingController();
  final _email = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _auth.me();
    if (!mounted) return;
    setState(() {
      _fullName.text = (user?['full_name'] ?? '').toString();
      _email.text = (user?['email'] ?? '').toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final err = await _data.updateProfile({
      'full_name': _fullName.text.trim(),
      'email': _email.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = err ?? 'Profil diperbarui.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Profil Saya', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _fullName,
          decoration: const InputDecoration(
              labelText: 'Nama Lengkap', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              labelText: 'Email', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_message!,
                style: TextStyle(
                    color: _message!.contains('diperbarui')
                        ? Colors.green
                        : Colors.red)),
          ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
