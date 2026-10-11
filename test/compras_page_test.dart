import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/data/repositorio.dart';
import 'package:compras/features/compras/compras_page.dart';
import 'package:compras/state/store.dart';
import 'store_test.dart' show RepositorioMemoria;

Future<(Store, RepositorioMemoria)> abrir(WidgetTester tester,
    {List<Compra> compras = const []}) async {
  final repo = RepositorioMemoria()..dados.compras.addAll(compras);
  final store = Store(repo);
  await store.carregar();
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: store, child: const MaterialApp(home: ComprasPage())));
  return (store, repo);
}

Future<void> preencherESalvar(WidgetTester tester, String valor) async {
  await tester.enterText(find.widgetWithText(TextField, 'Valor (R\$)'), valor);
  await tester.tap(find.text('Salvar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('valor em pt-BR com milhar é salvo', (tester) async {
    final (store, _) = await abrir(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await preencherESalvar(tester, '1.234,56');
    expect(store.compras.single.valor, 1234.56);
  });

  testWidgets('valor inválido mostra o motivo e não salva', (tester) async {
    final (store, repo) = await abrir(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    for (final (v, msg) in [
      ('NaN', 'Use só números, ponto ou vírgula'),
      ('Infinity', 'Use só números, ponto ou vírgula'),
      ('0', 'Informe um valor maior que zero'),
      ('', 'Informe o valor'),
      ('1.250', 'Ambíguo: para milhar escreva 1.250,00; para centavos, 1,25'),
      ('0,125', 'Use no máximo 2 casas decimais'),
    ]) {
      await preencherESalvar(tester, v);
      expect(find.text(msg), findsOneWidget, reason: v);
      expect(find.text('Nova compra'), findsOneWidget, reason: v);
    }
    expect(store.compras, isEmpty);
    expect(repo.salvamentos, 0);
  });

  testWidgets('o erro some ao corrigir o valor', (tester) async {
    await abrir(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await preencherESalvar(tester, '1.250');
    expect(find.textContaining('Ambíguo'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Valor (R\$)'), '1.250,00');
    await tester.pump();
    expect(find.textContaining('Ambíguo'), findsNothing);
  });

  testWidgets('cancelar não salva nada', (tester) async {
    final (store, repo) = await abrir(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Valor (R\$)'), '10');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(store.compras, isEmpty);
    expect(repo.salvamentos, 0);
  });

  testWidgets('editar compra de 1999 abre o seletor de data sem erro',
      (tester) async {
    await abrir(tester, compras: [Compra(DateTime(1999, 12, 31), 10)]);
    await tester.tap(find.text('Compra'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha ao salvar: avisa e a lista não mostra a compra',
      (tester) async {
    final (store, repo) = await abrir(tester);
    repo.falhaAoSalvar = const FalhaAoSalvar('disco cheio');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await preencherESalvar(tester, '10');

    expect(find.text('Não foi possível salvar: disco cheio'), findsOneWidget);
    expect(store.compras, isEmpty);
    expect(find.text('Toque em + para adicionar'), findsOneWidget);
  });

  testWidgets('falha ao excluir: avisa e a compra continua', (tester) async {
    final (store, repo) =
        await abrir(tester, compras: [Compra(DateTime.now(), 10)]);
    repo.falhaAoSalvar = const FalhaAoSalvar('disco cheio');
    await tester.tap(find.byTooltip('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não foi possível excluir'), findsOneWidget);
    expect(store.compras.length, 1);
  });

  testWidgets('erro inesperado: avisa e também reporta como defeito',
      (tester) async {
    final (store, repo) = await abrir(tester);
    repo.falhaAoSalvar = StateError('bug');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await preencherESalvar(tester, '10');

    expect(tester.takeException(), isA<StateError>());
    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    expect(store.compras, isEmpty);
  });

  testWidgets(
      'editar sem mexer no valor mantém o original, mesmo fora da regra',
      (tester) async {
    for (final original in [0.004, 2e12, -5.0]) {
      final (store, _) = await abrir(tester,
          compras: [Compra(DateTime(2026, 9, 1), original, descricao: 'X')]);
      await tester.tap(find.text('X'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Y');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(store.compras.single.valor, original, reason: '$original');
      expect(store.compras.single.descricao, 'Y');
    }
  });
}
