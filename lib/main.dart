import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/repositorio_prefs.dart';
import 'state/store.dart';

void main() {
  // trocar o armazenamento (SQLite, nuvem) = outra implementação de Repositorio aqui
  runApp(ChangeNotifierProvider(
      create: (_) => Store(RepositorioPrefs()), child: const App()));
}
