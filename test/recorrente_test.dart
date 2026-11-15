import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:compras/core/format.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/data/gastador.dart';
import 'package:compras/data/recorrente.dart';
import 'package:compras/data/repositorio.dart';
import 'package:compras/features/config/config_page.dart';
import 'package:compras/state/store.dart';
import 'store_test.dart' show RepositorioMemoria;

void main() {
  test('inicio: dia já passado começa no mês seguinte', () {
    final hoje = DateTime(2026, 11, 15);
    expect(Recorrente.inicio(10, hoje), DateTime(2026, 12));
    expect(Recorrente.inicio(15, hoje), DateTime(2026, 11)); // hoje conta
    expect(Recorrente.inicio(20, hoje), DateTime(2026, 11));
    // 31 em fevereiro é o dia 28: em 28/02 ainda entra
    expect(Recorrente.inicio(31, DateTime(2026, 2, 28)), DateTime(2026, 2));
    expect(Recorrente.inicio(1, DateTime(2026, 12, 2)), DateTime(2027, 1));
  });

  test('lancar: meses atrasados, dia limitado ao fim do mês', () {
    final r = Recorrente(31, 100, DateTime(2026, 9), descricao: 'Aluguel');
    final (gastos, rs) = lancar([r], {}, DateTime(2026, 11, 30));
    expect(gastos.map((c) => c.data),
        [DateTime(2026, 9, 30), DateTime(2026, 10, 31), DateTime(2026, 11, 30)]);
    expect(gastos.every((c) => c.valor == 100 && c.descricao == 'Aluguel'),
        isTrue);
    expect(rs.single.proximo, DateTime(2026, 12));
    expect(rs.single.id, r.id);
    // deNovo no mesmo dia: nada
    final (deNovo, _) = lancar(rs, {}, DateTime(2026, 11, 30));
    expect(deNovo, isEmpty);
  });

  test('lancar: antes do dia não lança', () {
    final r = Recorrente(20, 50, DateTime(2026, 11));
    final (gastos, rs) = lancar([r], {}, DateTime(2026, 11, 19, 23));
    expect(gastos, isEmpty);
    expect(identical(rs.single, r), isTrue);
  });

  test('lancar: divide entre os gastadores que ainda existem', () {
    final r = Recorrente(1, 100, DateTime(2026, 11), gastadores: ['a', 'b', 'x']);
    final (g, _) = lancar([r], {'a', 'b'}, DateTime(2026, 11, 1));
    expect(g.map((c) => (c.gastador, c.valor)), [('a', 50), ('b', 50)]);
    final (todos, _) = lancar([r], {}, DateTime(2026, 11, 1));
    expect(todos.single.gastador, ''); // ninguém sobrou: "Todos"
  });

  test('lancar: data absurda é limitada a $atrasoMaximoMeses meses', () {
    final r = Recorrente(1, 1, DateTime(1900));
    final (g, rs) = lancar([r], {}, DateTime(2026, 11, 15));
    expect(g.length, atrasoMaximoMeses + 1);
    expect(rs.single.proximo, DateTime(2026, 12));
  });

  test('JSON ida e volta; dia inválido é recusado', () {
    final r = Recorrente(5, 12.5, DateTime(2026, 11),
        descricao: 'Net', categoria: 'Casa', evento: 'E', gastadores: ['a']);
    final d = Dados.padrao()..recorrentes.add(r);
    final volta = Dados.deTexto(jsonEncode(d)).recorrentes.single;
    expect(jsonEncode(volta), jsonEncode(r));
    expect(() => Recorrente(0, 1, DateTime(2026)), throwsFormatException);
    expect(() => Recorrente(32, 1, DateTime(2026)), throwsFormatException);
    // backup v3, sem recorrentes, continua lendo
    expect(
        Dados.deTexto('{"versao": 3, "compras": [], "catCompra": [], '
                '"catEvento": []}')
            .recorrentes,
        isEmpty);
  });

  test('carregar lança os atrasados numa gravação só; sem nada, não grava',
      () async {
    final hoje = DateTime.now();
    final repo = RepositorioMemoria()
      ..dados.recorrentes
          .add(Recorrente(1, 10, DateTime(hoje.year, hoje.month - 2)));
    final store = Store(repo);
    await store.carregar();
    expect(store.compras.length, 3);
    expect(repo.salvamentos, 1);
    expect(store.recorrentes.single.proximo,
        DateTime(hoje.year, hoje.month + 1));
    await store.lancarRecorrentes();
    expect(repo.salvamentos, 1);
  });

  testWidgets('Config → recorrentes: criar, editar e excluir', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final hoje = DateTime.now();
    final repo = RepositorioMemoria()
      ..dados.gastadores.addAll([
        Gastador('Ana', DateTime(1990), Sexo.f, id: 'a'),
        Gastador('Bia', DateTime(1992), Sexo.f, id: 'b'),
      ]);
    final store = Store(repo);
    await store.carregar();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: store, child: const MaterialApp(home: ConfigPage())));
    await tester.tap(find.text('Gastos recorrentes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Novo gasto recorrente'), findsOneWidget);
    expect(find.textContaining('Parcelas'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Net');
    await tester.enterText(find.widgetWithText(TextField, 'Valor (R\$)'), '80');

    // dia inválido: erro e nada salvo
    await tester.enterText(
        find.widgetWithText(TextField, 'Dia do mês (1 a 31)'), '0');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe de 1 a 31'), findsOneWidget);
    expect(store.recorrentes, isEmpty);

    // dia de hoje, dividido entre todos: já lança hoje
    await tester.enterText(
        find.widgetWithText(TextField, 'Dia do mês (1 a 31)'), '${hoje.day}');
    await tester.tap(find.text('Todos'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(store.recorrentes.single.gastadores, ['a', 'b']);
    expect(store.compras.map((c) => (c.gastador, c.valor)),
        unorderedEquals([('a', 40.0), ('b', 40.0)]));
    expect(find.text('Net'), findsOneWidget);
    expect(find.textContaining('Todo dia ${hoje.day}'), findsOneWidget);

    // editar o valor
    await tester.tap(find.text('Net'));
    await tester.pumpAndSettle();
    expect(find.text('Editar gasto recorrente'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Valor (R\$)'), '90');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(store.recorrentes.single.valor, 90);
    expect(store.compras.length, 2, reason: 'o mês já lançado não repete');
    expect(find.text(fmtValor(90)), findsOneWidget);

    // excluir: os gastos já lançados ficam
    await tester.tap(find.byTooltip('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(store.recorrentes, isEmpty);
    expect(store.compras.length, 2);
    expect(store.compras.first, isA<Compra>());
  });
}
