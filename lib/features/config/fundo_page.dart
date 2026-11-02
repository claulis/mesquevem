import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ambiente.dart';
import '../../core/salvar.dart';
import '../../state/fundo.dart';

/// Devolve os bytes da imagem escolhida, ou null se o usuário cancelou.
typedef EscolherImagem = Future<List<int>?> Function();

Future<List<int>?> escolherComSeletor() => doAmbiente(() async {
      final f = await FilePicker.pickFile(type: FileType.image);
      return f == null ? null : await f.readAsBytes();
    }, 'erro do seletor de arquivos');

class FundoPage extends StatelessWidget {
  final EscolherImagem escolherImagem;
  const FundoPage({this.escolherImagem = escolherComSeletor, super.key});

  @override
  Widget build(BuildContext context) {
    final fundo = context.watch<Fundo>();
    final arquivo = fundo.arquivo;
    return Scaffold(
      appBar: AppBar(title: const Text('Personalização do fundo')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
            'Coloque uma imagem de quem, ou que, te inspira a gastar menos ou '
            'de quem, ou que, te faz gastar mais 😄',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        if (arquivo != null) ...[
          // prévia como fica na tela principal: a imagem com a opacidade
          // escolhida sobre o fundo do app
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Opacity(
                opacity: fundo.opacidade,
                child: Image.file(arquivo,
                    height: 240, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Opacidade da imagem: ${(fundo.opacidade * 100).round()}%'),
          Slider(
            value: fundo.opacidade,
            min: 0.05,
            max: 1,
            divisions: 19, // de 5 em 5%
            label: '${(fundo.opacidade * 100).round()}%',
            // falha ao gravar: a opacidade vale nesta sessão, sem quebrar
            onChanged: (v) => fundo.definirOpacidade(v).ignore(),
          ),
          Text(
              'Quanto menor, mais legíveis ficam os números na tela '
              'principal.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.image),
          label: Text(arquivo == null ? 'Escolher imagem' : 'Trocar imagem'),
          onPressed: () => avisandoFalha(context, () async {
            final bytes = await escolherImagem();
            if (bytes != null) await fundo.definir(bytes);
          }, falha: 'Não foi possível usar a imagem'),
        ),
        if (arquivo != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.hide_image),
            label: const Text('Remover imagem'),
            onPressed: () => avisandoFalha(context, fundo.remover,
                falha: 'Não foi possível remover'),
          ),
        ],
      ]),
    );
  }
}
