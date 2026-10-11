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
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Previsão para o mês que vem'),
          const SizedBox(height: 8),
          Text(fmtValor(valor),
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text('Método: $metodo', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(children: [
          for (final f in features)
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, f.rota),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(f.icone),
                      Text(f.rotulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12)),
                    ]),
              ),
            ),
        ]),
      ),
    );
  }
}
