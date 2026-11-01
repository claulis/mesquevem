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
        if (arquivo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(arquivo, height: 240, fit: BoxFit.cover),
          ),
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
