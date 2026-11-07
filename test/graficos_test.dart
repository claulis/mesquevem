import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:compras/core/format.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/features/graficos/graficos.dart';
import 'package:compras/features/graficos/graficos_page.dart';
import 'package:compras/state/store.dart';
import 'store_test.dart' show RepositorioMemoria;

void main() {
  final out = DateTime(2026, 10);
  final cs = [
    Compra(DateTime(2026, 10, 1), 10, categoria: 'A', gastador: 'g1'), // qui
    Compra(DateTime(2026, 10, 1), 5, categoria: 'B'),
    Compra(DateTime(2026, 10, 4), 20, categoria: 'A', evento: 'Festa'), // dom
    Compra(DateTime(2026, 9, 15), 30, categoria: 'A'),
    Compra(DateTime(2026, 8, 15), 60, categoria: 'B'),
    Compra(DateTime(2025, 10, 2), 100, evento: 'Festa'),
    Compra(DateTime(2024, 10, 2), 999, evento: 'Festa'), // fora dos 2 anos
  ];

  test('totaisMensais: n meses até o mês, do mais antigo ao mais novo', () {
    final t = totaisMensais(cs, out, n: 3);
    expect(t.map((e) => e.$1.month), [8, 9, 10]);
    expect(t.map((e) => e.$2), [60, 30, 35]);
    // virada de ano
    expect(totaisMensais(cs, DateTime(2026, 1), n: 2).first.$1,
        DateTime(2025, 12));
  });

  test('porDia e acumulado', () {
    final d = porDia(cs, out);
    expect(d.length, 31);
    expect(d[0], 15);
    expect(d[3], 20);
    expect(acumulado([1, 2, 3]), [1, 3, 6]);
    expect(acumulado(d).last, 35);
  });

  test('porGastador usa o nome; sem gastador vira Todos', () {
    final r = porGastador(cs, out, (id) => id.isEmpty ? 'Todos' : 'Ana');
    expect(r, {'Ana': 10, 'Todos': 25});
  });

  test('mediaPorCategoria: média dos 3 meses anteriores', () {
    final m = mediaPorCategoria(cs, out);
    expect(m['A'], 10); // 30 / 3
    expect(m['B'], 20); // 60 / 3
  });

  test('eventosPorAno: este ano × anterior, sem os sem evento', () {
    expect(eventosPorAno(cs, 2026), {'Festa': (20.0, 100.0)});
  });

  test('porDiaDaSemana: índice 0 = domingo, só os últimos n meses', () {
    final s = porDiaDaSemana(cs, out, n: 1);
    expect(s[4], 15); // quinta, 1/10
    expect(s[0], 20); // domingo, 4/10
    expect(s.reduce((a, b) => a + b), 35);
  });

  test('composicao: 7 maiores e o resto em Outras', () {
    final m = {for (var i = 1; i <= 9; i++) 'c$i': i.toDouble(), '': 0.5};
    final r = composicao(m);
    expect(r.length, 8);
    expect(r.first, ('c9', 9.0));
    expect(r.last, ('Outras', 1 + 2 + 0.5));
    expect(composicao({'': 3, 'x': 0}), [('Sem categoria', 3.0)]);
  });

  testWidgets('tela de gráficos mostra os 8 e respeita o ocultar valores',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 4000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final hoje = DateTime.now();
    final repo = RepositorioMemoria()
      ..dados.compras.addAll([
        Compra(hoje, 1234.5, categoria: 'Alimentação', evento: 'Natal'),
        Compra(DateTime(hoje.year, hoje.month - 1, 3), 80,
            categoria: 'Lazer'),
      ]);
    final store = Store(repo);
    await store.carregar();
    Future<void> montar() async {
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(home: GraficosPage(DateTime(hoje.year, hoje.month)))));
      await tester.pumpAndSettle();
    }

    await montar();
    for (final t in [
      'Últimos 6 meses',
      'Ritmo do mês',
      'Por gastador',
      'Categorias: mês × média',
      'Mapa de calor',
      'Custo por evento',
      'Composição por categoria',
      'Por dia da semana',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.textContaining('1.234,50'), findsWidgets);

    valoresOcultos = true;
    addTearDown(() => valoresOcultos = false);
    await montar();
    expect(find.textContaining('1.234,50'), findsNothing);
    expect(find.textContaining(mascaraValor), findsWidgets);
  });
}
