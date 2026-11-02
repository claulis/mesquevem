import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/confirmar.dart';
import '../../core/ambiente.dart';
import '../../core/salvar.dart';
import '../../data/repositorio.dart';
import '../../state/store.dart';
import 'principal_page.dart';

/// Carrega os dados; mostra a home ou, se falhar, a tela de erro.
class InicioPage extends StatefulWidget {
  const InicioPage({super.key});
  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  late final Store _store;
  late Future<void> _carga;

  @override
  void initState() {
    super.initState();
    _store = context.read<Store>();
    _carga = _store.carregar();
  }

  // corpo em bloco: setState não aceita callback que devolve Future
  void _repetir(Future<void> Function() acao) => setState(() {
        _carga = acao();
      });

  // se falhar, continua na mesma tela de erro (com os mesmos botões) e avisa
  Future<void> _recomecar() async {
    if (await avisandoFalha(context, _store.recomecar,
            falha: 'Não foi possível começar do zero') &&
        mounted) {
      setState(() {
        _carga = Future.value(); // corpo em bloco: ver _repetir
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _carga,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (s.hasError) {
            return ErroPage(
              erro: s.error!,
              tentarDeNovo: () => _repetir(_store.carregar),
              recomecar: _recomecar,
            );
          }
          return const PrincipalPage();
        },
      );
}

class ErroPage extends StatelessWidget {
  final Object erro;
  final VoidCallback tentarDeNovo, recomecar;
  const ErroPage(
      {required this.erro,
      required this.tentarDeNovo,
      required this.recomecar,
      super.key});

  @override
  Widget build(BuildContext context) {
    // "começar do zero" só quando os dados estão de fato ilegíveis; numa falha
    // passageira (ex.: armazenamento indisponível) apagaria dados bons.
    final e = erro;
    final corrompido = e is DadosCorrompidos ? e : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Erro ao abrir')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Icon(Icons.error_outline,
            size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text(switch (corrompido) {
          null => 'Não foi possível carregar os dados.',
          DadosCorrompidos(copiaGuardada: true) =>
            'Os dados salvos não puderam ser lidos. '
                'Uma cópia deles foi guardada no aparelho.',
          _ => 'Os dados salvos não puderam ser lidos, e não foi possível '
              'guardar uma cópia (armazenamento cheio?). Use "Copiar dados" '
              'antes de começar do zero, para não perdê-los.',
        }),
        const SizedBox(height: 8),
        Text(mensagem(corrompido?.causa ?? erro),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
            onPressed: tentarDeNovo),
        if (corrompido != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar dados'),
            onPressed: () async {
              final msg = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: corrompido.bruto));
              msg.showSnackBar(const SnackBar(
                  content:
                      Text('Dados copiados para a área de transferência')));
            },
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: const Text('Começar do zero'),
            onPressed: () async {
              // sem cópia, é a única saída (armazenamento cheio), mas a
              // confirmação deixa claro que os dados se perdem
              if (await confirmar(
                  context,
                  corrompido.copiaGuardada
                      ? 'Apagar os dados ilegíveis e começar do zero? '
                          'A cópia guardada continua no aparelho.'
                      : 'NÃO há cópia dos dados ilegíveis: eles serão perdidos. '
                          'Use "Copiar dados" antes. Apagar e começar do zero?',
                  acao: 'Apagar')) {
                recomecar();
              }
            },
          ),
        ],
      ]),
    );
  }
}
