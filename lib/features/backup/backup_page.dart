import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/confirmar.dart';
import '../../core/ambiente.dart';
import '../../core/erros.dart';
import '../../core/salvar.dart';
import '../../data/repositorio.dart';
import '../../state/store.dart';

/// Devolve false se o usuário cancelou.
typedef SalvarArquivo = Future<bool> Function(String nome, String texto);

/// Devolve null se o usuário cancelou.
typedef AbrirArquivo = Future<String?> Function();

typedef CompartilharArquivo = Future<void> Function(String nome, String texto);

Future<void> compartilharComSistema(String nome, String texto) => doAmbiente(
    () => SharePlus.instance.share(ShareParams(files: [
          XFile.fromData(utf8.encode(texto),
              name: nome, mimeType: 'application/json')
        ], fileNameOverrides: [
          nome
        ])),
    'erro ao compartilhar');

Future<bool> salvarComSeletor(String nome, String texto) => doAmbiente(
    () async =>
        await FilePicker.saveFile(
            fileName: nome,
            bytes: utf8.encode(texto),
            mimeType: 'application/json') !=
        null,
    'erro do seletor de arquivos');

/// Bytes que não são UTF-8 lançam [FormatException] (arquivo inválido), não
/// [ErroDoApp] (problema do ambiente).
Future<String?> abrirComSeletor() async {
  final bytes = await doAmbiente(() async {
    final f = await FilePicker.pickFile();
    return f == null ? null : await f.readAsBytes();
  }, 'erro do seletor de arquivos');
  return bytes == null ? null : utf8.decode(bytes);
}

class BackupPage extends StatelessWidget {
  final SalvarArquivo salvarArquivo;
  final AbrirArquivo abrirArquivo;
  final CompartilharArquivo compartilhar;
  const BackupPage(
      {this.salvarArquivo = salvarComSeletor,
      this.abrirArquivo = abrirComSeletor,
      this.compartilhar = compartilharComSistema,
      super.key});

  static String _nomeArquivo() =>
      'mesquevem-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json';

  Future<void> _exportar(BuildContext context) async {
    final store = context.read<Store>();
    final msg = ScaffoldMessenger.of(context);
    await avisandoFalha(context, () async {
      final texto = await store.exportar();
      if (await salvarArquivo(_nomeArquivo(), texto)) {
        msg.showSnackBar(const SnackBar(content: Text('Backup salvo')));
      }
    }, falha: 'Não foi possível salvar o backup');
  }

  Future<void> _compartilhar(BuildContext context) async {
    final store = context.read<Store>();
    await avisandoFalha(context,
        () async => compartilhar(_nomeArquivo(), await store.exportar()),
        falha: 'Não foi possível compartilhar o backup');
  }

  Future<void> _importar(BuildContext context) async {
    final store = context.read<Store>();
    final msg = ScaffoldMessenger.of(context);
    Dados? dados;
    final aberto = await avisandoFalha(context, () async {
      try {
        // dentro do try: arquivo que não é UTF-8 também é "arquivo inválido"
        final texto = await abrirArquivo();
        if (texto != null) dados = Dados.deTexto(texto);
      } on DadosDeVersaoMaisNova {
        throw const ErroDoApp('o backup é de uma versão mais nova do app; '
            'atualize o app para importá-lo');
      } on FormatException catch (e) {
        throw ErroDoApp('arquivo inválido (${e.message})');
      }
    }, falha: 'Não foi possível importar, nada foi alterado');
    final lido = dados;
    if (!aberto || lido == null) return;
    if (!context.mounted) return;
    final ok = await confirmar(
        context,
        'Substituir TODOS os dados atuais (${store.compras.length} compras e '
        'categorias) pelos do arquivo (${lido.compras.length} compras)?\n\n'
        'Exporte antes se quiser guardar os dados atuais.',
        acao: 'Importar');
    if (!ok || !context.mounted) return;
    if (await avisandoFalha(context, () => store.importar(lido),
        falha: 'Não foi possível importar, nada foi alterado')) {
      msg.showSnackBar(const SnackBar(content: Text('Dados importados')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final nCat = store.categorias(TipoCategoria.compra).length +
        store.categorias(TipoCategoria.evento).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup e compartilhamento')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
            'Neste aparelho: ${store.compras.length} compras e $nCat categorias.'),
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
        FilledButton.tonalIcon(
            icon: const Icon(Icons.share),
            label: const Text('Compartilhar backup'),
            onPressed: () => _compartilhar(context)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Importar dados'),
            onPressed: () => _importar(context)),
      ]),
    );
  }
}
