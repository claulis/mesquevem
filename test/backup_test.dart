import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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

    final d = Dados.deTexto(origem.exportar());
    final c = d.compras.single;
    expect([c.id, c.data, c.valor, c.descricao, c.categoria, c.evento], [
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

  testWidgets('exportar entrega o JSON ao arquivo', (tester) async {
    String? salvo;
    final repo = RepositorioMemoria()
      ..dados.compras.add(Compra(DateTime(2026, 9, 1), 7));
    await abrirBackup(tester, repo, salvar: (nome, texto) async {
      expect(nome, startsWith('compras-backup-'));
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

    expect(find.textContaining('Arquivo inválido'), findsOneWidget);
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
}
