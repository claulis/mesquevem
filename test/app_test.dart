import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:compras/app.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/data/repositorio.dart';
import 'package:compras/state/store.dart';
import 'store_test.dart' show RepositorioMemoria;

/// Falha nas primeiras [falhas] cargas com [erro].
class RepositorioComFalha extends RepositorioMemoria {
  final Object erro;
  int falhas;
  RepositorioComFalha(this.erro, {this.falhas = 1});
  @override
  Future<Dados> carregar() async {
    if (falhas-- > 0) throw erro;
    return super.carregar();
  }
}

Future<void> abrir(WidgetTester tester, RepositorioMemoria repo) async {
  await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => Store(repo), child: const App()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('app monta e todas as telas da barra abrem', (tester) async {
    await abrir(
        tester,
        RepositorioMemoria()
          ..dados.compras.add(Compra(DateTime.now(), 42, descricao: 'Pão')));

    expect(find.text('Previsão para o mês que vem'), findsOneWidget);
    expect(find.text('R\$ 42,00'), findsOneWidget);

    for (final (botao, titulo) in [
      ('Cadastro compra', 'Compras'),
      ('Categoria evento', 'Categorias de evento'),
      ('Categoria compra', 'Categorias de compra'),
      ('Backup', 'Backup'),
    ]) {
      await tester.tap(find.text(botao));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, titulo), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('excluir compra pela tela remove do store', (tester) async {
    await abrir(
        tester,
        RepositorioMemoria()
          ..dados.compras.add(Compra(DateTime.now(), 10, descricao: 'Café')));

    await tester.tap(find.text('Cadastro compra'));
    await tester.pumpAndSettle();
    expect(find.text('Café'), findsOneWidget);
    await tester.tap(find.byTooltip('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Toque em + para adicionar'), findsOneWidget);
  });

  testWidgets('dados corrompidos: começar do zero abre a home', (tester) async {
    final repo = RepositorioComFalha(
        const DadosCorrompidos('{lixo', FormatException('inválido')));
    await abrir(tester, repo);

    expect(find.text('Erro ao abrir'), findsOneWidget);
    await tester.tap(find.text('Começar do zero'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir')); // confirmação
    await tester.pumpAndSettle();

    expect(find.text('Previsão para o mês que vem'), findsOneWidget);
    expect(repo.salvamentos, 1);
  });

  testWidgets('falha passageira: só tentar de novo, sem apagar', (tester) async {
    final repo = RepositorioComFalha(Exception('disco indisponível'));
    await abrir(tester, repo);

    expect(find.text('Erro ao abrir'), findsOneWidget);
    expect(find.text('Começar do zero'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Previsão para o mês que vem'), findsOneWidget);
    expect(repo.salvamentos, 0);
  });
}
