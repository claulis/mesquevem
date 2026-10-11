import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../state/store.dart';
import '../features.dart';
import 'previsao.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final (valor, metodo) =
        previsao(context.watch<Store>().compras, DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Previsão')),
      // rolável: com fonte grande o conteúdo pode não caber na tela
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Previsão para o mês que vem',
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(fmtValor(valor),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 8),
            Text('Método: $metodo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
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
