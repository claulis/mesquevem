import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:compras/core/erros.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/data/repositorio.dart';
import 'package:compras/features/backup/backup_page.dart';
import 'package:compras/state/store.dart';
import 'store_test.dart' show RepositorioMemoria;

Future<Store> abrirBackup(WidgetTester tester, RepositorioMemoria repo,
    {SalvarArquivo? salvar, AbrirArquivo? abrir}) async {
  final store = Store(repo);
  await store.carregar();
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(
        home: BackupPage(
            salvarArquivo: salvar ?? (_, __) async => true,
            abrirArquivo: abrir ?? () async => null)),
  ));
  return store;
}

void main() {
  test('backup leva todos os dados e volta igual', () async {
    final origem = Store(RepositorioMemoria());
    await origem.carregar();
    await origem.salvarCompra(Compra(DateTime(2026, 9, 1), 12.5,
        descricao: 'Pão', categoria: 'Padaria', evento: 'Natal'));
    await origem.adicionarCategoria(TipoCategoria.compra, 'Padaria');
    await origem.adicionarCategoria(TipoCategoria.evento, 'Páscoa');

    final d = Dados.deTexto(await origem.exportar());
    final c = d.compras.single;
    expect([
      c.id,
      c.data,
      c.valor,
      c.descricao,
      c.categoria,
      c.evento
    ], [
      origem.compras.single.id,
      DateTime(2026, 9, 1),
      12.5,
      'Pão',
      'Padaria',
      'Natal'
    ]);
    expect(d.catCompra, origem.categorias(TipoCategoria.compra));
    expect(d.catEvento, origem.categorias(TipoCategoria.evento));
  });

  test('arquivo inválido ou de versão mais nova é recusado', () {
    for (final texto in [
      'não é json',
      '[1, 2]',
      '{}',
      '{"versao": 99, "compras": [], "catCompra": [], "catEvento": []}',
    ]) {
      expect(() => Dados.deTexto(texto), throwsA(anything), reason: texto);
    }
  });

  test('campos de tipo errado viram FormatException legível', () {
    for (final texto in [
      '{"versao": "2", "compras": [], "catCompra": [], "catEvento": []}',
      '{"versao": 2, "compras": {}, "catCompra": [], "catEvento": []}',
      '{"versao": 2, "compras": [], "catCompra": [1], "catEvento": []}',
      '{"versao": 1, "compras": [1], "catCompra": [], "catEvento": []}',
      '{"versao": 2, "compras": [{"data": 1, "valor": 2}], '
          '"catCompra": [], "catEvento": []}',
    ]) {
      expect(() => Dados.deTexto(texto), throwsFormatException, reason: texto);
    }
  });

  test('versão absurda é formato inválido, não "versão mais nova"', () {
    for (final v in ['1e300', '1e400', '-1', '2.5', '"2"']) {
      expect(
          () => Dados.deTexto('{"versao": $v, "compras": [], '
              '"catCompra": [], "catEvento": []}'),
          throwsA(isA<FormatException>()
              .having((e) => e, 'tipo', isNot(isA<DadosDeVersaoMaisNova>()))),
          reason: v);
    }
  });

  test('categorias vazias ou repetidas do backup são descartadas', () {
    final d = Dados.deTexto('{"versao": 2, "compras": [], '
        '"catCompra": ["Lazer", "", "Lazer", "  ", "Outros"], '
        '"catEvento": ["A", "A"]}');
    expect(d.catCompra, ['Lazer', 'Outros']);
    expect(d.catEvento, ['A']);
  });

  test('valor que o JSON não grava é recusado; antigos ficam', () {
    String backup(String valor) => '{"versao": 2, "compras": [{"id": "a", '
        '"data": "2026-09-01T00:00:00.000", "valor": $valor}], '
        '"catCompra": [], "catEvento": []}';
    for (final v in ['1e400', '-1e400']) {
      expect(() => Dados.deTexto(backup(v)), throwsFormatException, reason: v);
    }
    // 1e21: o app antigo deixava digitar; recusar tornaria tudo ilegível
    for (final v in ['0', '-5', '2e12', '0.004', '1e21', '5e25']) {
      expect(Dados.deTexto(backup(v)).compras.single.valor, double.parse(v),
          reason: v);
    }
  });

  test('nomes de categoria são comparados sem espaços nas pontas', () {
    final d = Dados.deTexto('{"versao": 2, "compras": [{"id": "a", '
        '"data": "2026-09-01T00:00:00.000", "valor": 1, '
        '"categoria": "Lazer ", "evento": " Natal"}], '
        '"catCompra": ["Lazer", "Lazer "], "catEvento": [" Natal"]}');
    expect(d.catCompra, ['Lazer']);
    expect(d.catEvento, ['Natal']);
    expect(d.compras.single.categoria, 'Lazer');
    expect(d.compras.single.evento, 'Natal');
  });

  test('versão 2.0 (número decimal) é aceita', () {
    expect(
        Dados.deTexto('{"versao": 2.0, "compras": [], "catCompra": ["A"], '
                '"catEvento": []}')
            .catCompra,
        ['A']);
  });

  testWidgets('versão mais nova: mensagem sem prefixo técnico', (tester) async {
    await abrirBackup(tester, RepositorioMemoria(),
        abrir: () async =>
            '{"versao": 99, "compras": [], "catCompra": [], "catEvento": []}');
    await tester.tap(find.text('Importar dados'));
    await tester.pumpAndSettle();
    expect(find.textContaining('versão mais nova do app'), findsOneWidget);
    expect(find.textContaining('arquivo inválido'), findsNothing);
    expect(find.textContaining('FormatException'), findsNothing);
  });

  testWidgets('arquivo que não é UTF-8 é "inválido", não falha do ambiente',
      (tester) async {
    await abrirBackup(tester, RepositorioMemoria(),
        abrir: () async =>
            throw const FormatException('Missing extension byte'));
    await tester.tap(find.text('Importar dados'));
    await tester.pumpAndSettle();
    expect(find.textContaining('arquivo inválido'), findsOneWidget);
  });

  testWidgets('erro inesperado ao abrir: avisa e reporta como defeito',
      (tester) async {
    await abrirBackup(tester, RepositorioMemoria(),
        abrir: () async => throw StateError('bug'));
    await tester.tap(find.text('Importar dados'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isA<StateError>());
    expect(find.textContaining('Não foi possível importar'), findsOneWidget);
  });

  testWidgets('falha do seletor ao salvar ou abrir é avisada', (tester) async {
    await abrirBackup(tester, RepositorioMemoria(),
        salvar: (_, __) async => throw const ErroDoApp('sem permissão'),
        abrir: () async => throw const ErroDoApp('arquivo sumiu'));
    await tester.tap(find.text('Exportar dados'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível salvar o backup: sem permissão'),
        findsOneWidget);
    expect(find.text('Backup salvo'), findsNothing);

    ScaffoldMessenger.of(tester.element(find.text('Importar dados')))
        .removeCurrentSnackBar();
    await tester.tap(find.text('Importar dados'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Não foi possível importar, nada foi alterado: arquivo sumiu'),
        findsOneWidget);
  });

  testWidgets('exportar entrega o JSON ao arquivo', (tester) async {
    String? salvo;
    final repo = RepositorioMemoria()
      ..dados.compras.add(Compra(DateTime(2026, 9, 1), 7));
    await abrirBackup(tester, repo, salvar: (nome, texto) async {
      expect(nome, startsWith('mesquevem-backup-'));
      salvo = texto;
      return true;
    });

    await tester.tap(find.text('Exportar dados'));
    await tester.pumpAndSettle();
    expect(Dados.deTexto(salvo!).compras.single.valor, 7);
    expect(find.text('Backup salvo'), findsOneWidget);
  });

  testWidgets('importar substitui tudo após confirmar', (tester) async {
    final backup = Dados.padrao()
      ..compras.add(Compra(DateTime(2026, 8, 1), 99, descricao: 'Do backup'))
      ..catEvento.add('Páscoa');
    final repo = RepositorioMemoria()
      ..dados.compras.add(Compra(DateTime(2026, 9, 1), 1, descricao: 'Atual'));
    final store =
        await abrirBackup(tester, repo, abrir: () async => jsonEncode(backup));

    await tester.tap(find.text('Importar dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(store.compras.single.descricao, 'Do backup');
    expect(store.categorias(TipoCategoria.evento), contains('Páscoa'));
    expect(repo.salvamentos, 1);
  });

  testWidgets('importar arquivo inválido não altera nada', (tester) async {
    final repo = RepositorioMemoria()
      ..dados.compras.add(Compra(DateTime(2026, 9, 1), 1));
    final store = await abrirBackup(tester, repo, abrir: () async => '{lixo');

    await tester.tap(find.text('Importar dados'));
    await tester.pumpAndSettle();

    expect(find.textContaining('arquivo inválido'), findsOneWidget);
    expect(store.compras.length, 1);
    expect(repo.salvamentos, 0);
  });

  testWidgets('cancelar a confirmação não altera nada', (tester) async {
    final repo = RepositorioMemoria()
      ..dados.compras.add(Compra(DateTime(2026, 9, 1), 1));
    final store = await abrirBackup(tester, repo,
        abrir: () async => Store(RepositorioMemoria()).exportar());

    await tester.tap(find.text('Importar dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(store.compras.length, 1);
    expect(repo.salvamentos, 0);
  });

  test('backup salvo com BOM (editor do Windows) é aceito', () async {
    final texto = '\uFEFF${await Store(RepositorioMemoria()).exportar()}';
    expect(Dados.deTexto(texto).catCompra, isNotEmpty);
  });

  testWidgets('falha ao salvar na importação: avisa e nada muda',
      (tester) async {
    final backup = Dados.padrao()
      ..compras.add(Compra(DateTime(2026, 8, 1), 99, descricao: 'Do backup'));
    final repo = RepositorioMemoria()
      ..dados.compras.add(Compra(DateTime(2026, 9, 1), 1, descricao: 'Atual'));
    final store =
        await abrirBackup(tester, repo, abrir: () async => jsonEncode(backup));
    repo.falhaAoSalvar = const FalhaAoSalvar('disco cheio');

    await tester.tap(find.text('Importar dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não foi possível importar'), findsOneWidget);
    expect(find.text('Dados importados'), findsNothing);
    expect(store.compras.single.descricao, 'Atual');
  });
}
