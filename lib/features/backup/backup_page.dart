import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/confirmar.dart';
import '../../core/ambiente.dart';
import '../../core/erros.dart';
import '../../core/format.dart';
import '../../core/salvar.dart';
import '../../data/repositorio.dart';
import '../../state/nuvem.dart';
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
  final f = await doAmbiente(
      () => FilePicker.pickFile(), 'erro do seletor de arquivos');
  if (f == null) return null;
  return utf8.decode(await lerComLimite(f.readAsByteStream()));
}

/// Backup real tem centenas de KB; acima disso não é backup do app.
const tamanhoMaximoBackup = 10 * 1024 * 1024;

/// Lê em pedaços e para assim que passar de [limite]: um arquivo gigante
/// (ou malicioso) não chega a ser carregado inteiro na memória. Passou do
/// limite: [FormatException] (arquivo inválido, nada é importado).
Future<List<int>> lerComLimite(Stream<List<int>> bytes,
    {int limite = tamanhoMaximoBackup}) async {
  final lido = BytesBuilder(copy: false);
  await doAmbiente(() async {
    await for (final b in bytes) {
      lido.add(b);
      if (lido.length > limite) break;
    }
  }, 'erro ao ler o arquivo');
  if (lido.length > limite) {
    throw FormatException('arquivo grande demais para ser um backup '
        '(máximo ${limite ~/ (1024 * 1024)} MB)');
  }
  return lido.takeBytes();
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
        'Substituir TODOS os dados atuais (${store.compras.length} gastos e '
        'categorias) pelos do arquivo (${lido.compras.length} gastos)?\n\n'
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
        // opcional: os testes montam a tela sem ela
        if (context.watch<Nuvem?>() case final n?) ...[
          SecaoDrive(n),
          const Divider(height: 32),
        ],
        Text(
            'Neste aparelho: ${store.compras.length} gastos e $nCat categorias.'),
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

String _quando(DateTime d) => '${fmtData(d)} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Login Google e backup automático no Drive (pasta oculta do app).
class SecaoDrive extends StatelessWidget {
  final Nuvem nuvem;
  const SecaoDrive(this.nuvem, {super.key});

  Future<void> _entrar(BuildContext context) async {
    final store = context.read<Store>();
    if (!await avisandoFalha(context, nuvem.entrar,
        falha: 'Não foi possível entrar')) {
      return;
    }
    // aparelho novo (sem gastos): oferece trazer o backup do Drive
    if (store.compras.isEmpty && context.mounted) {
      await _restaurar(context, soSeHouver: true);
    }
  }

  Future<void> _restaurar(BuildContext context,
      {bool soSeHouver = false}) async {
    final store = context.read<Store>();
    final msg = ScaffoldMessenger.of(context);
    ({Dados dados, DateTime quando})? b;
    if (!await avisandoFalha(context, () async => b = await nuvem.baixar(),
        falha: 'Não foi possível restaurar, nada foi alterado')) {
      return;
    }
    final lido = b;
    if (lido == null) {
      if (!soSeHouver) {
        msg.showSnackBar(
            const SnackBar(content: Text('Ainda não há backup no Drive')));
      }
      return;
    }
    if (!context.mounted) return;
    final ok = await confirmar(
        context,
        'Substituir TODOS os dados atuais (${store.compras.length} gastos e '
        'categorias) pelos do backup do Drive de ${_quando(lido.quando)} '
        '(${lido.dados.compras.length} gastos)?',
        acao: 'Restaurar');
    if (!ok || !context.mounted) return;
    if (await avisandoFalha(context, () => store.importar(lido.dados),
        falha: 'Não foi possível restaurar, nada foi alterado')) {
      msg.showSnackBar(const SnackBar(content: Text('Dados restaurados')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final n = nuvem;
    final pequeno = tema.textTheme.bodySmall;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Google Drive', style: tema.textTheme.titleMedium),
      const SizedBox(height: 8),
      if (!n.configurado)
        Text('Backup no Google Drive não configurado nesta versão.',
            style: pequeno)
      else if (n.email == null) ...[
        Text(
            'Entre com a sua conta Google para guardar uma cópia automática '
            'dos dados no seu Drive (pasta oculta, só o app vê).',
            style: pequeno),
        const SizedBox(height: 8),
        FilledButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Entrar com Google'),
            onPressed: n.ocupado ? null : () => _entrar(context)),
      ] else ...[
        Text('Conta: ${n.email}'),
        Text(n.ultimoBackup == null
            ? 'Ainda sem backup no Drive'
            : 'Último backup: ${_quando(n.ultimoBackup!)}'),
        Text('O backup é feito sozinho quando você sai do app.',
            style: pequeno),
        if (n.erro != null)
          Text('Último backup automático falhou: ${n.erro}',
              style: TextStyle(color: tema.colorScheme.error)),
        const SizedBox(height: 8),
        FilledButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: Text(n.ocupado ? 'Enviando…' : 'Fazer backup agora'),
            onPressed: n.ocupado
                ? null
                : () => avisandoFalha(context, n.backupAgora,
                    falha: 'Não foi possível fazer o backup')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            icon: const Icon(Icons.cloud_download),
            label: const Text('Restaurar do Drive'),
            onPressed: n.ocupado ? null : () => _restaurar(context)),
        TextButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Sair da conta'),
            onPressed: n.ocupado ? null : n.sair),
      ],
    ]);
  }
}
