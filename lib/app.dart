import 'package:flutter/material.dart';
import 'features/config/atualizar_page.dart';
import 'features/inicio/inicio_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  /// Para abrir telas e mostrar avisos de fora da árvore de widgets (toque
  /// na notificação, verificação de versão ao abrir o app).
  static final navegador = GlobalKey<NavigatorState>();
  static final mensagens = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mês que Vem',
        navigatorKey: navegador,
        scaffoldMessengerKey: mensagens,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const InicioPage(),
        routes: {'/atualizar': (_) => const AtualizarPage()},
      );
}
