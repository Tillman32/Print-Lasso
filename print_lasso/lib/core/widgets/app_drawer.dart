import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.onHome, this.onSettings});

  final VoidCallback? onHome;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.teal),
            child: Text(
              'Print Lasso',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              onHome?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Print Jobs'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to print jobs page
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              onSettings?.call();
            },
          ),
        ],
      ),
    );
  }
}
