import 'package:flutter/material.dart';
import '../compras/compras_page.dart';
import '../config/config_page.dart';
import '../previsao/home_page.dart';

/// Barra de baixo com as três áreas do app. A aba atual fica destacada;
/// IndexedStack mantém cada aba como estava (rolagem, por exemplo).
class PrincipalPage extends StatefulWidget {
  const PrincipalPage({super.key});
  @override
  State<PrincipalPage> createState() => _PrincipalPageState();
}

class _PrincipalPageState extends State<PrincipalPage> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
            index: _aba,
            children: const [HomePage(), ComprasPage(), ConfigPage()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _aba,
          onDestinationSelected: (i) => setState(() => _aba = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Início'),
            NavigationDestination(
                icon: Icon(Icons.shopping_cart_outlined),
                selectedIcon: Icon(Icons.shopping_cart),
                label: 'Compras'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Config'),
          ],
        ),
      );
}
