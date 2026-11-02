import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:compras/app.dart';
import 'package:compras/features/previsao/home_page.dart';
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

/// Item da barra de baixo (o mesmo texto pode ser também o título da tela).
Finder aba_(String rotulo) => find.descendant(
    of: find.byType(NavigationBar), matching: find.text(rotulo));

Future<void> abrir(WidgetTester tester, RepositorioMemoria repo) async {
  await tester.pumpWidget(
      ChangeNotifierProvider(create: (_) => Store(repo), child: const App()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('app monta e todas as telas da barra abrem', (tester) async {
    await abrir(
        tester,
        RepositorioMemoria()
          ..dados.compras.add(Compra(DateTime.now(), 42, descricao: 'Pão')));

    expect(find.text('Previsão para o mês que vem'), findsOneWidget);
    expect(find.text('R\$ 42,00'), findsWidgets);

    // abas: a atual fica destacada na barra
    for (final (aba, titulo) in [
      ('Compras', 'Compras'),
      ('Config', 'Config')
    ]) {
      await tester.tap(aba_(aba));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, titulo), findsOneWidget);
    }
    // cadastros que mudam pouco ficam dentro de Config
    for (final titulo in [
      'Categorias de compra',
      'Categorias de evento',
      'Gastadores',
    ]) {
      await tester.tap(find.text(titulo));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, titulo), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await tester.tap(aba_('Início'));
    await tester.pumpAndSettle();
    expect(find.text('Previsão para o mês que vem'), findsOneWidget);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
  });

  testWidgets('botão + Compra da tela principal cadastra direto',
      (tester) async {
    final repo = RepositorioMemoria();
    await abrir(tester, repo);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Compra'));
    await tester.pumpAndSettle();
    expect(find.text('Nova compra'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Valor (R\$)'), '12,50');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(repo.dados.compras.single.valor, 12.5);
  });

  testWidgets('excluir compra pela tela remove do store', (tester) async {
    await abrir(
        tester,
        RepositorioMemoria()
          ..dados.compras.add(Compra(DateTime.now(), 10, descricao: 'Café')));

    await tester.tap(aba_('Compras'));
    await tester.pumpAndSettle();
    expect(find.text('Café'), findsOneWidget);
    await tester.tap(find.byTooltip('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Toque em + para adicionar'), findsOneWidget);
  });

  testWidgets('dados corrompidos: detalhe sem prefixo técnico', (tester) async {
    await abrir(
        tester,
        RepositorioComFalha(const DadosCorrompidos(
            '{lixo', FormatException('campo ruim'),
            copiaGuardada: true)));
    expect(find.text('campo ruim'), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);
  });

  testWidgets('corrompido sem cópia: copiar e começar do zero com aviso',
      (tester) async {
    final repo = RepositorioComFalha(const DadosCorrompidos(
        '{lixo', FormatException('x'),
        copiaGuardada: false));
    await abrir(tester, repo);
    expect(find.text('Copiar dados'), findsOneWidget);
    expect(find.textContaining('não foi possível guardar uma cópia'),
        findsOneWidget);

    await tester.tap(find.text('Começar do zero'));
    await tester.pumpAndSettle();
    expect(find.textContaining('NÃO há cópia'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Erro ao abrir'), findsOneWidget);
    expect(repo.salvamentos, 0);
  });

  testWidgets('começar do zero que falha: fica na tela de erro e avisa',
      (tester) async {
    final repo = RepositorioComFalha(const DadosCorrompidos(
        '{lixo', FormatException('x'),
        copiaGuardada: true))
      ..falhaAoSalvar = const FalhaAoSalvar('disco cheio');
    await abrir(tester, repo);
    await tester.tap(find.text('Começar do zero'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível começar do zero: disco cheio'),
        findsOneWidget);
    expect(find.text('Erro ao abrir'), findsOneWidget);
    expect(find.text('Copiar dados'), findsOneWidget);
    expect(find.text('Começar do zero'), findsOneWidget);
  });

  testWidgets('dados corrompidos: começar do zero abre a home', (tester) async {
    final repo = RepositorioComFalha(const DadosCorrompidos(
        '{lixo', FormatException('inválido'),
        copiaGuardada: true));
    await abrir(tester, repo);

    expect(find.text('Erro ao abrir'), findsOneWidget);
    await tester.tap(find.text('Começar do zero'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar')); // confirmação
    await tester.pumpAndSettle();

    expect(find.text('Previsão para o mês que vem'), findsOneWidget);
    expect(repo.salvamentos, 1);
  });

  testWidgets('falha passageira: só tentar de novo, sem apagar',
      (tester) async {
    final repo = RepositorioComFalha(Exception('disco indisponível'));
    await abrir(tester, repo);

    expect(find.text('Erro ao abrir'), findsOneWidget);
    expect(find.text('Começar do zero'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Previsão para o mês que vem'), findsOneWidget);
    expect(repo.salvamentos, 0);
  });

  testWidgets('dados de versão mais nova: sem "começar do zero"',
      (tester) async {
    final repo = RepositorioComFalha(DadosDeVersaoMaisNova(versaoAtual + 1));
    await abrir(tester, repo);

    expect(find.text('Erro ao abrir'), findsOneWidget);
    expect(find.textContaining('atualize o app'), findsOneWidget);
    expect(find.text('Começar do zero'), findsNothing);
    expect(find.text('Copiar dados'), findsNothing);
  });

  testWidgets('barra inferior aguenta fonte grande e tela estreita',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await abrir(tester, RepositorioMemoria());

    expect(tester.takeException(), isNull);
    await tester.tap(aba_('Config'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Config'), findsOneWidget);
  });

  testWidgets('tema segue o modo escuro do celular', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await abrir(tester, RepositorioMemoria());
    final ctx = tester.element(find.text('Previsão para o mês que vem'));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(corDoLimite(ctx), corLimiteEscuro);
  });
}
