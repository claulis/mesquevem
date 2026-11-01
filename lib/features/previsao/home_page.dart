import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../state/fundo.dart';
import '../../state/store.dart';
import '../features.dart';
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
      body: DecoratedBox(
        decoration: BoxDecoration(
          image: fundo == null
              ? null
              // translúcida, para o texto continuar legível
              : DecorationImage(
                  image: FileImage(fundo), fit: BoxFit.cover, opacity: 0.3),
        ),
        // rolável: com fonte grande o conteúdo pode não caber na tela
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Previsão para o mês que vem',
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(fmtValor(valor),
              textAlign: TextAlign.center, style: tema.displayMedium),
          const SizedBox(height: 8),
          Text('Método: $metodo',
              textAlign: TextAlign.center, style: tema.bodySmall),
          const Divider(height: 32),
          const Text('Gasto neste mês', textAlign: TextAlign.center),
          Text(fmtValor(mes.total),
              textAlign: TextAlign.center, style: tema.headlineMedium),
          if (teto != null)
            Text('Teto: ${fmtValor(teto)}',
                textAlign: TextAlign.center,
                style: tema.titleMedium?.copyWith(color: corTeto)),
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
