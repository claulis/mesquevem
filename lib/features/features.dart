import 'package:flutter/material.dart';
import '../state/store.dart';
import 'backup/backup_page.dart';
import 'categorias/categoria_page.dart';
import 'compras/compras_page.dart';

class Feature {
  final IconData icone;
  final String rotulo, rota;
  final WidgetBuilder builder;
  const Feature(this.icone, this.rotulo, this.rota, this.builder);
}

/// Telas acessíveis pela barra inferior da home. Tela nova = uma entrada aqui;
/// a rota nomeada é registrada automaticamente em app.dart.
final features = [
  Feature(Icons.shopping_cart, 'Cadastro compra', '/compras',
      (_) => const ComprasPage()),
  Feature(Icons.event, 'Categoria evento', '/categorias/evento',
      (_) => const CategoriaPage(TipoCategoria.evento)),
  Feature(Icons.label, 'Categoria compra', '/categorias/compra',
      (_) => const CategoriaPage(TipoCategoria.compra)),
  Feature(Icons.import_export, 'Backup', '/backup', (_) => const BackupPage()),
];
