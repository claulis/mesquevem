import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/data/gastador.dart';
import 'package:compras/data/repositorio.dart';
import 'package:compras/features/previsao/home_page.dart';
import 'package:compras/features/previsao/resumo.dart';
import 'package:compras/state/store.dart';
import 'store_test.dart' show RepositorioMemoria;

void main() {
  late RepositorioMemoria repo;
  late Store store;
  const t = TipoCategoria.compra;
  setUp(() async {
    repo = RepositorioMemoria();
    store = Store(repo);
    await store.carregar();
  });

  test('dados v2 (sem os campos novos) abrem sem limites, gastadores e teto',
      () {
    final d = Dados.deTexto('{"versao": 2, "compras": [{"id": "a", '
        '"data": "2026-09-01T00:00:00.000", "valor": 5}], '
        '"catCompra": ["Lazer"], "catEvento": []}');
    expect(d.compras.single.gastador, '');
    expect(d.limCompra, isEmpty);
    expect(d.gastadores, isEmpty);
    expect(d.teto, isNull);
  });

  test('backup leva limites, gastadores, gastador da compra e teto', () async {
    final g = Gastador('Ana', DateTime(2015, 3, 4), Sexo.f);
    await store.salvarGastador(g);
    await store.adicionarCategoria(t, 'Padaria', limite: 200);
    await store.salvarCompra(Compra(DateTime(2026, 9, 1), 7, gastador: g.id));
    await store.definirTeto(3000);

    final d = Dados.deTexto(await store.exportar());
    expect(jsonDecode(await store.exportar())['versao'], versaoAtual);
    expect(d.limCompra, {'Padaria': 200});
    expect(d.gastadores.single.toJson(), g.toJson());
    expect(d.compras.single.gastador, g.id);
    expect(d.teto, 3000);
  });

  test('limite segue a categoria renomeada e some com ela', () async {
    await store.editarCategoria(t, 'Lazer', 'Diversão', 150);
    expect(store.limite(t, 'Diversão'), 150);
    expect(store.limite(t, 'Lazer'), isNull);
    await store.removerCategoria(t, 'Diversão');
    expect(repo.dados.limCompra, isEmpty);
  });

  test('mudar só o limite salva; nada mudou não salva', () async {
    await store.editarCategoria(t, 'Lazer', 'Lazer', 100);
    expect(store.limite(t, 'Lazer'), 100);
    final n = repo.salvamentos;
    await store.editarCategoria(t, 'Lazer', 'Lazer', 100);
    expect(repo.salvamentos, n);
  });

  test('limite inválido ou de categoria inexistente no backup', () {
    String b(String lim) => '{"versao": 3, "compras": [], "catCompra": '
        '["Lazer"], "catEvento": [], "limCompra": $lim}';
    expect(() => Dados.deTexto(b('{"Lazer": -1}')), throwsFormatException);
    expect(Dados.deTexto(b('{"Sumiu": 10, " Lazer ": 5}')).limCompra,
        {'Lazer': 5});
  });

  test('excluir gastador passa as compras dele para Todos', () async {
    final g = Gastador('Bia', DateTime(2010), Sexo.outro);
    await store.salvarGastador(g);
    await store.salvarCompra(Compra(DateTime(2026, 9, 1), 7, gastador: g.id));
    expect(store.nomeGastador(g.id), 'Bia');
    await store.removerGastador(g.id);
    expect(store.gastadores, isEmpty);
    expect(store.compras.single.gastador, '');
    expect(store.nomeGastador(g.id), 'Todos');
  });

  test('teto: define e remove', () async {
    await store.definirTeto(2500);
    expect(store.teto, 2500);
    await store.definirTeto(null);
    expect(store.teto, isNull);
    expect(repo.dados.teto, isNull);
  });

  test('gastoDoMes conta só o mês atual', () {
    final r = gastoDoMes([
      Compra(DateTime(2026, 9, 2), 10, categoria: 'Lazer', evento: 'Natal'),
      Compra(DateTime(2026, 9, 30), 5, categoria: 'Lazer'),
      Compra(DateTime(2026, 8, 31), 100, categoria: 'Lazer'),
    ], DateTime(2026, 9, 15));
    expect(r.total, 15);
    expect(r.porCategoria['Lazer'], 15);
    expect(r.porEvento['Natal'], 10);
  });

  testWidgets('home: teto em azul, limite em azul claro e vermelho se passou',
      (tester) async {
    // tela alta: a home é uma lista preguiçosa, só monta o que aparece
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hoje = DateTime.now();
    // fora do relógio falso do teste (senão a fila do Store não anda)
    await tester.runAsync(() async {
      await store.adicionarCategoria(t, 'Padaria', limite: 50);
      await store.editarCategoria(t, 'Lazer', 'Lazer', 10);
      await store.salvarCompra(Compra(hoje, 20, categoria: 'Padaria'));
      await store.salvarCompra(Compra(hoje, 30, categoria: 'Lazer'));
      await store.definirTeto(1000);
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: store, child: const MaterialApp(home: HomePage())));

    Color? cor(String texto) =>
        tester.widget<Text>(find.text(texto)).style?.color;
    expect(cor('Teto: R\$ 1000,00'), corTeto);
    expect(cor('Limite: R\$ 50,00'), corLimite);
    expect(cor('Limite: R\$ 10,00'), corAcima);
  });

  testWidgets('home: sem teto cadastrado não mostra a linha', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: store, child: const MaterialApp(home: HomePage())));
    expect(find.textContaining('Teto'), findsNothing);
  });
}
