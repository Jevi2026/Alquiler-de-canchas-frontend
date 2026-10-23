import 'package:flutter/material.dart';
import '../models/auth_user.dart';

class AppDrawer extends StatelessWidget {
  final AuthUser user;
  final VoidCallback onLogout;
  final bool busy;

  const AppDrawer({
    super.key,
    required this.user,
    required this.onLogout,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user.greeting),
              accountEmail: Text(user.email),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Inicio'),
              selected: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            const ListTile(
              leading: Icon(Icons.people_outline),
              title: Text('Usuarios'),
              subtitle: Text('Proximamente'),
              enabled: false,
            ),
            // Agregue aqui las opciones propias de su proyecto.
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesion'),
              enabled: !busy,
              onTap: busy
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      onLogout();
                    },
            ),
          ],
        ),
      ),
    );
  }
}
