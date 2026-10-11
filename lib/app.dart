import 'package:flutter/material.dart';
import 'features/features.dart';
import 'features/inicio/inicio_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Compras',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const InicioPage(),
        routes: {for (final f in features) f.rota: f.builder},
      );
}
