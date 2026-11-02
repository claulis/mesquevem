import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../state/fundo.dart';
import '../../state/store.dart';
import '../compras/compras_page.dart';
import 'insights.dart';
import 'insights_page.dart';
import 'previsao.dart';
import 'resumo.dart';

/// Cores pedidas para o limite (azul claro) e o teto (azul); acima do limite,
/// vermelho.
const corLimite = Colors.lightBlue,
    corTeto = Colors.blue,
    corAcima = Colors.red;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// Linha de uma categoria: nome e gasto do mês; embaixo, o limite (se
  /// houver) em azul claro, ou vermelho se o gasto passou dele, com uma barra
  /// de gasto ÷ limite.
  static Widget _categoria(String nome, double gasto, double? limite) {
    final acima = limite != null && gasto > limite;
    final cor = acima ? corAcima : corLimite;
    return ListTile(
      dense: true,
      title: Text(nome),
      subtitle: limite == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Limite: ${fmtValor(limite)}',
                    style: TextStyle(color: cor)),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (gasto / limite).clamp(0.0, 1.0),
                  color: cor,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
      trailing: Text(fmtValor(gasto),
          style: acima ? const TextStyle(color: corAcima) : null),
    );
  }

  /// Seção "Por categoria"/"Por evento": as com gasto no mês, da maior para
  /// a menor. As sem gasto ficam recolhidas (categorias) ou somem (eventos,
  /// que só fazem sentido no mês em que acontecem).
  static List<Widget> _secao(BuildContext context, Store store, String titulo,
      TipoCategoria tipo, Map<String, double> gastos) {
    double g(String n) => gastos[n] ?? 0;
    final nomes = [...store.categorias(tipo)]
      ..sort((a, b) => g(b).compareTo(g(a)));
    final com = nomes.where((n) => g(n) > 0).toList();
    final sem = nomes.where((n) => g(n) <= 0).toList();
    if (tipo == TipoCategoria.evento && com.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      Text(titulo, style: Theme.of(context).textTheme.titleSmall),
      for (final n in com) _categoria(n, g(n), store.limite(tipo, n)),
      if (tipo == TipoCategoria.compra && sem.isNotEmpty)
        ExpansionTile(
          dense: true,
          title: Text('Sem gasto neste mês (${sem.length})'),
          children: [
            for (final n in sem) _categoria(n, 0, store.limite(tipo, n)),
          ],
        ),
    ];
  }

  /// Gasto do mês sobre o teto, com uma marca no ritmo ideal para hoje
  /// (dia de hoje / dias do mês). Azul; vermelha se passou do teto.
  static Widget _barraTeto(
      BuildContext context, double gasto, double teto, DateTime hoje) {
    final ideal = hoje.day / diasNoMes(hoje.year, hoje.month);
    final trilho = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(children: [
      const SizedBox(height: 8),
      SizedBox(
        key: const Key('barraTeto'),
        height: 14,
        child: LayoutBuilder(
          builder: (context, c) => Stack(children: [
            Container(
                decoration: BoxDecoration(
                    color: trilho, borderRadius: BorderRadius.circular(7))),
            FractionallySizedBox(
              widthFactor: (gasto / teto).clamp(0.0, 1.0),
              child: Container(
                  decoration: BoxDecoration(
                      color: gasto > teto ? corAcima : corTeto,
                      borderRadius: BorderRadius.circular(7))),
            ),
            Positioned(
              left: (c.maxWidth * ideal - 1).clamp(0.0, c.maxWidth - 2),
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: Colors.black54),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      Text(
          '${fmtValor(gasto)} de ${fmtValor(teto)} · ideal até hoje: '
          '${fmtValor(teto * ideal)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final hoje = DateTime.now();
    final (valor, metodo) = previsao(store.compras, hoje);
    final mes = gastoDoMes(store.compras, hoje);
    final teto = store.teto;
    // opcional: os testes montam o app sem ele
    final fundo = context.watch<Fundo?>()?.arquivo;
    final tema = Theme.of(context).textTheme;
    final nInsights = insightsDe(store, hoje).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Mês que Vem'), actions: [
        // contador como o de notificações: some quando não há insight
        IconButton(
          tooltip: 'Insights',
          icon: Badge(
            label: Text('$nInsights'),
            isLabelVisible: nInsights > 0,
            child: const Icon(Icons.lightbulb_outline),
          ),
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const InsightsPage())),
        ),
      ]),
      // a ação mais frequente do app, a um toque
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // há outro botão flutuante na aba Compras
        icon: const Icon(Icons.add),
        label: const Text('Compra'),
        onPressed: () => ComprasPage.formulario(context),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          image: fundo == null
              ? null
              // translúcida, para o texto continuar legível
              : DecorationImage(
                  image: FileImage(fundo), fit: BoxFit.cover, opacity: 0.3),
        ),
        // rolável: com fonte grande o conteúdo pode não caber na tela;
        // embaixo, espaço para o botão "+ Compra" não cobrir a última linha
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              // o que se acompanha no dia a dia vem primeiro: o mês atual
              Card(
                key: const Key('cartaoMes'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Text('Gasto em ${meses[hoje.month - 1]}',
                        textAlign: TextAlign.center),
                    Text(fmtValor(mes.total),
                        textAlign: TextAlign.center, style: tema.displaySmall),
                    if (teto != null) ...[
                      Text('Teto: ${fmtValor(teto)}',
                          textAlign: TextAlign.center,
                          style: tema.titleMedium?.copyWith(color: corTeto)),
                      _barraTeto(context, mes.total, teto, hoje),
                      const SizedBox(height: 8),
                      if (mes.total > teto)
                        Text('Teto estourado em ${fmtValor(mes.total - teto)}',
                            textAlign: TextAlign.center,
                            style: tema.titleSmall?.copyWith(color: corAcima))
                      else
                        Text(
                            'Pode gastar '
                            '${fmtValor(porDiaAteOFim(mes.total, teto, hoje))} '
                            'por dia até o fim do mês',
                            textAlign: TextAlign.center,
                            style: tema.titleSmall),
                    ],
                  ]),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Previsão para o mês que vem'),
                  subtitle: Text(fmtValor(valor), style: tema.titleLarge),
                  trailing: IconButton(
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'Como é calculada',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Como é calculada'),
                        content: Text('Método: $metodo.\n\nO método muda '
                            'conforme o histórico de meses cresce.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ..._secao(context, store, 'Por categoria', TipoCategoria.compra,
                  mes.porCategoria),
              ..._secao(context, store, 'Por evento', TipoCategoria.evento,
                  mes.porEvento),
            ]),
      ),
    );
  }
}
