import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/privacidade.dart';
import '../../state/store.dart';
import 'home_page.dart' show corAcima;
import 'insights.dart';
import 'previsao.dart';

/// Os insights de hoje para os dados do [store], alertas primeiro.
/// [valorPrevisto]: a previsão já calculada (a Home tem), para não refazer.
List<Insight> insightsDe(Store store, DateTime hoje, {double? valorPrevisto}) =>
    [
      ...insights(
        compras: store.compras,
        hoje: hoje,
        teto: store.teto,
        limCompra: store.limites(TipoCategoria.compra),
        limEvento: store.limites(TipoCategoria.evento),
        gastadores: store.gastadores,
        previsao: valorPrevisto ?? previsao(store.compras, hoje).$1,
      ),
    ]..sort((a, b) => (b.alerta ? 1 : 0) - (a.alerta ? 1 : 0));

/// Todos os cartões de insight. Aberta pelo botão com o contador na Home.
class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<Privacidade?>(); // redesenha ao ocultar/mostrar valores
    final lista = insightsDe(context.watch<Store>(), DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: lista.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum insight agora. Eles aparecem conforme '
                    'você registra compras e define teto e limites.'),
              ),
            )
          : ListView(padding: const EdgeInsets.all(8), children: [
              for (final i in lista)
                Card(
                  child: ListTile(
                    leading: i.alerta
                        ? const Icon(Icons.warning_amber, color: corAcima)
                        : const Icon(Icons.lightbulb_outline),
                    title: Text(i.texto),
                  ),
                ),
            ]),
    );
  }
}
