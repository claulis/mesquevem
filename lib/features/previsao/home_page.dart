import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../state/fundo.dart';
import '../../state/store.dart';
import '../compras/compras_page.dart';
import '../features.dart';
import 'insights.dart';
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
  /// houver) em azul claro, ou vermelho se o gasto passou dele.
  static Widget _categoria(String nome, double gasto, double? limite) {
    final acima = limite != null && gasto > limite;
    return ListTile(
      dense: true,
      title: Text(nome),
      subtitle: limite == null
          ? null
          : Text('Limite: ${fmtValor(limite)}',
              style: TextStyle(color: acima ? corAcima : corLimite)),
      trailing: Text(fmtValor(gasto),
          style: acima ? const TextStyle(color: corAcima) : null),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Mês que Vem')),
      // a ação mais frequente do app, a um toque
      floatingActionButton: FloatingActionButton.extended(
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
              const SizedBox(height: 8),
              for (final i in insights(
                compras: store.compras,
                hoje: hoje,
                teto: teto,
                limCompra: store.limites(TipoCategoria.compra),
                limEvento: store.limites(TipoCategoria.evento),
                gastadores: store.gastadores,
                previsao: valor,
              ))
                Card(
                  child: ListTile(
                    dense: true,
                    leading: i.alerta
                        ? const Icon(Icons.warning_amber, color: corAcima)
                        : const Icon(Icons.lightbulb_outline),
                    title: Text(i.texto),
                  ),
                ),
              for (final (titulo, tipo, gastos) in [
                ('Por categoria', TipoCategoria.compra, mes.porCategoria),
                ('Por evento', TipoCategoria.evento, mes.porEvento),
              ]) ...[
                const SizedBox(height: 16),
                Text(titulo, style: tema.titleSmall),
                for (final nome in store.categorias(tipo))
                  _categoria(nome, gastos[nome] ?? 0, store.limite(tipo, nome)),
              ],
            ]),
      ),
      // altura pelo conteúdo (não fixa), para aguentar fonte grande do sistema
      bottomNavigationBar: Material(
        // mesma cor da BottomAppBar do Material 3
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: SafeArea(
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final f in features)
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(context, f.rota),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(f.icone),
                            Text(f.rotulo,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12)),
                          ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
