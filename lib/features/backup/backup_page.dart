import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/confirmar.dart';
import '../../data/repositorio.dart';
import '../../state/store.dart';

/// Devolve false se o usuário cancelou.
typedef SalvarArquivo = Future<bool> Function(String nome, String texto);

/// Devolve null se o usuário cancelou.
typedef AbrirArquivo = Future<String?> Function();

Future<bool> salvarComSeletor(String nome, String texto) async =>
    await FilePicker.saveFile(
        fileName: nome,
        bytes: utf8.encode(texto),
        mimeType: 'application/json') !=
    null;

Future<String?> abrirComSeletor() async {
  final f = await FilePicker.pickFile();
  return f == null ? null : utf8.decode(await f.readAsBytes());
}

class BackupPage extends StatelessWidget {
  final SalvarArquivo salvarArquivo;
  final AbrirArquivo abrirArquivo;
  const BackupPage(
      {this.salvarArquivo = salvarComSeletor,
      this.abrirArquivo = abrirComSeletor,
      super.key});

  Future<void> _exportar(BuildContext context) async {
    final store = context.read<Store>();
    final msg = ScaffoldMessenger.of(context);
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    try {
      if (await salvarArquivo('compras-backup-$hoje.json', store.exportar())) {
        msg.showSnackBar(const SnackBar(content: Text('Backup salvo')));
      }
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
    }
  }

  Future<void> _importar(BuildContext context) async {
    final store = context.read<Store>();
    final msg = ScaffoldMessenger.of(context);
    final Dados dados;
    try {
      final texto = await abrirArquivo();
      if (texto == null) return;
      dados = Dados.deTexto(texto);
    } catch (e) {
      msg.showSnackBar(SnackBar(
          content: Text('Arquivo inválido, nada foi alterado. ($e)')));
      return;
    }
    if (!context.mounted) return;
    final ok = await confirmar(
        context,
        'Substituir TODOS os dados atuais (${store.compras.length} compras e '
        'categorias) pelos do arquivo (${dados.compras.length} compras)?\n\n'
        'Exporte antes se quiser guardar os dados atuais.',
        acao: 'Importar');
    if (!ok) return;
    await store.importar(dados);
    msg.showSnackBar(const SnackBar(content: Text('Dados importados')));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final nCat = store.categorias(TipoCategoria.compra).length +
        store.categorias(TipoCategoria.evento).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Neste aparelho: ${store.compras.length} compras e $nCat categorias.'),
        const SizedBox(height: 8),
        Text(
            'O arquivo de backup leva todos os dados e não é criptografado: '
            'guarde-o em um lugar seguro.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Exportar dados'),
            onPressed: () => _exportar(context)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Importar dados'),
            onPressed: () => _importar(context)),
      ]),
    );
  }
}
