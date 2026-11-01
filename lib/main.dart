import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/repositorio_prefs.dart';
import 'state/fundo.dart';
import 'state/store.dart';

void main() {
  // trocar o armazenamento (SQLite, nuvem) = outra implementação de Repositorio aqui
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => Store(RepositorioPrefs())),
    ChangeNotifierProvider(create: (_) => Fundo()..carregar()),
  ], child: const App()));
}
