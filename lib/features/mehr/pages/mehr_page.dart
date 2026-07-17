import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MehrPage extends StatelessWidget {
  const MehrPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mehr')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Recherche'),
            onTap: () => context.go('/recherche'),
          ),
          ListTile(
            leading: const Icon(Icons.checklist_outlined),
            title: const Text('Entscheidungen'),
            onTap: () => context.go('/entscheidungen'),
          ),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Konto'),
            onTap: () => context.go('/konto'),
          ),
        ],
      ),
    );
  }
}
