import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/data/gastador.dart';
import 'package:compras/features/previsao/home_page.dart';
import 'package:compras/features/previsao/insights.dart';
import 'package:compras/state/store.dart';
import 'store_test.dart' show RepositorioMemoria;

List<String> textos(
  List<Compra> compras, {
  DateTime? hoje,
  double? teto,
  Map<String, double> limCompra = const {},
  List<Gastador> gastadores = const [],
  double previsao = 0,
}) =>
    insights(
      compras: compras,
      hoje: hoje ?? DateTime(2026, 9, 10),
      teto: teto,
      limCompra: limCompra,
      limEvento: const {},
      gastadores: gastadores,
      previsao: previsao,
    ).map((i) => i.texto).toList();

void main() {
  // 10/09: 10 de 30 dias
  final dia10 = DateTime(2026, 9, 10);

  test('ritmo e quanto pode gastar por dia', () {
    final t = textos([Compra(dia10, 100)], teto: 600);
    expect(
        t,
        contains('No ritmo atual você fecha o mês em R\$ 300,00 '
            '(teto R\$ 600,00)'));
    // (600 - 100) / 21 dias restantes contando hoje
    expect(t, contains('Pode gastar R\$ 23,81 por dia até o fim do mês'));
  });

  test('teto estourado é alerta e troca o "pode gastar"', () {
    final i = insights(
        compras: [Compra(dia10, 700)],
        hoje: dia10,
        teto: 600,
        limCompra: const {},
        limEvento: const {},
        gastadores: const [],
        previsao: 0);
    expect(i.map((x) => x.texto), contains('Teto estourado em R\$ 100,00'));
    expect(i.map((x) => x.texto), isNot(contains(startsWith('Pode gastar'))));
    expect(i.every((x) => x.texto.startsWith('No ritmo') ? x.alerta : true),
        isTrue);
  });

  test('sem teto, nada sobre teto', () {
    final t = textos([Compra(dia10, 100)], previsao: 9999);
    expect(t.where((x) => x.contains('teto') || x.contains('Pode gastar')),
        isEmpty);
  });

  test('mês passado: mesmo período, 31 de março vira até 28 de fevereiro', () {
    final t = textos([
      Compra(DateTime(2026, 3, 31), 115),
      Compra(DateTime(2026, 2, 28), 100),
      Compra(DateTime(2026, 2, 27), 0.001), // arredonda, não muda o %
    ], hoje: DateTime(2026, 3, 31));
    expect(
        t, contains('Até hoje: 15% a mais que no mesmo período de fevereiro'));
    expect(textos([Compra(dia10, 50), Compra(DateTime(2026, 8, 11), 999)]),
        isNot(contains(startsWith('Até hoje'))),
        reason: 'compra de agosto depois do dia 10 não entra');
  });

  test('limite: 80% avisa, 79% não', () {
    expect(
        textos([Compra(dia10, 80, categoria: 'Lazer')],
            limCompra: {'Lazer': 100}),
        contains('Lazer já usou 80% do limite'));
    expect(
        textos([Compra(dia10, 79.9, categoria: 'Lazer')],
            limCompra: {'Lazer': 100}),
        isNot(contains(contains('do limite'))));
  });

  test('categoria que mais cresceu sobre a média de 3 meses', () {
    final t = textos([
      for (final m in [6, 7, 8]) ...[
        Compra(DateTime(2026, m, 5), 300, categoria: 'Lazer'),
        Compra(DateTime(2026, m, 5), 100, categoria: 'Feira'),
      ],
      Compra(dia10, 500, categoria: 'Lazer'),
      Compra(dia10, 150, categoria: 'Feira'),
    ]);
    expect(
        t,
        contains('Lazer: R\$ 500,00 neste mês, acima da média de '
            'R\$ 300,00 dos últimos 3 meses'));
    expect(t, isNot(contains(startsWith('Feira:'))));
  });

  test('aniversário no mês que vem, inclusive na virada do ano', () {
    final ana = Gastador('Ana', DateTime(2015, 1, 3), Sexo.f);
    expect(textos([], hoje: DateTime(2026, 12, 5), gastadores: [ana]),
        contains('Aniversário de Ana em janeiro: reserve um valor'));
    expect(textos([], hoje: DateTime(2026, 1, 5), gastadores: [ana]),
        isNot(contains(startsWith('Aniversário'))));
  });

  test('previsão acima do teto', () {
    expect(textos([], teto: 1000, previsao: 1200),
        contains('A previsão do mês que vem passa do teto em R\$ 200,00'));
  });

  testWidgets('home: barra do teto só com teto cadastrado', (tester) async {
    final store = Store(RepositorioMemoria());
    await tester.runAsync(store.carregar);
    Future<void> montar() => tester.pumpWidget(ChangeNotifierProvider.value(
        value: store, child: const MaterialApp(home: HomePage())));

    await montar();
    expect(find.byKey(const Key('barraTeto')), findsNothing);

    await tester.runAsync(() async {
      await store.definirTeto(1000);
      await store.salvarCompra(Compra(DateTime.now(), 10));
    });
    await montar();
    await tester.pump();
    expect(find.byKey(const Key('barraTeto')), findsOneWidget);
    expect(find.textContaining('Pode gastar'), findsOneWidget);
  });
}
