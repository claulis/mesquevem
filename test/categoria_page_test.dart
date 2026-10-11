import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:compras/data/repositorio.dart';
import 'package:compras/features/categorias/categoria_page.dart';
import 'package:compras/state/store.dart';
import 'store_test.dart' show RepositorioMemoria;

Future<(Store, RepositorioMemoria)> abrir(WidgetTester tester) async {
  final repo = RepositorioMemoria();
  final store = Store(repo);
  await store.carregar();
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: store,
      child: const MaterialApp(home: CategoriaPage(TipoCategoria.compra))));
  return (store, repo);
}

Future<void> digitarESalvar(WidgetTester tester, String nome) async {
  await tester.enterText(find.byType(TextField), nome);
  await tester.tap(find.text('Salvar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nome vazio ou repetido: diálogo fica aberto com o motivo',
      (tester) async {
    final (store, repo) = await abrir(tester);
    final antes = store.categorias(TipoCategoria.compra);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await digitarESalvar(tester, '   ');
    expect(find.text('Informe um nome'), findsOneWidget);
    await digitarESalvar(tester, ' Lazer ');
    expect(find.text('Já existe uma categoria com esse nome'), findsOneWidget);
    expect(find.text('Nova categoria'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Padaria');
    await tester.pump();
    expect(find.text('Já existe uma categoria com esse nome'), findsNothing,
        reason: 'o erro some ao digitar');
    await digitarESalvar(tester, 'Padaria');
    expect(find.text('Nova categoria'), findsNothing);
    expect(store.categorias(TipoCategoria.compra), [...antes, 'Padaria']);
    expect(repo.salvamentos, 1);
  });

  testWidgets('renomear: mesmo nome fecha sem salvar; outro existente recusa',
      (tester) async {
    final (store, repo) = await abrir(tester);
    await tester.tap(find.text('Lazer'));
    await tester.pumpAndSettle();
    await digitarESalvar(tester, 'Outros');
    expect(find.text('Já existe uma categoria com esse nome'), findsOneWidget);

    await digitarESalvar(tester, 'Lazer');
    expect(find.text('Editar categoria'), findsNothing);
    expect(repo.salvamentos, 0);
    expect(store.categorias(TipoCategoria.compra), contains('Lazer'));
  });

  testWidgets('falha ao salvar: avisa e a categoria não aparece',
      (tester) async {
    final (store, repo) = await abrir(tester);
    repo.falhaAoSalvar = const FalhaAoSalvar('disco cheio');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await digitarESalvar(tester, 'Padaria');

    expect(find.text('Não foi possível salvar: disco cheio'), findsOneWidget);
    expect(store.categorias(TipoCategoria.compra), isNot(contains('Padaria')));
    expect(find.text('Padaria'), findsNothing);
  });
}
