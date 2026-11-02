import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/atualizador.dart';

String _mb(int bytes) =>
    (bytes / 1048576).toStringAsFixed(1).replaceAll('.', ',');

/// Mostra o [Atualizador], que vive no app inteiro: sair da tela e voltar
/// não perde o progresso.
class AtualizarPage extends StatelessWidget {
  const AtualizarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<Atualizador>();
    final r = a.release;
    final tema = Theme.of(context);
    final pct = a.total > 0 ? a.recebidos / a.total : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Atualizar')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(a.atual > 0
            ? 'Versão instalada: v${a.versao}'
            : 'Versão de desenvolvimento'),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Verificar atualização'),
          onPressed:
              a.rodando || a.fase == Fase.verificando ? null : a.verificar,
        ),
        const SizedBox(height: 16),
        if (a.fase == Fase.verificando) const Text('Verificando…'),
        if (r != null && !a.temNovaVersao(r) && !a.rodando)
          Text(a.atual > 0
              ? 'Você já está na última versão 🎉'
              : 'A última versão publicada é ${r.tag}; instale pelo GitHub.'),
        if (r != null && a.temNovaVersao(r)) ...[
          Text('Nova versão ${r.tag} disponível!',
              style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
              'Seus dados continuam no app. Se quiser, faça um backup antes '
              '(Config → Backup e compartilhamento).',
              style: tema.textTheme.bodySmall),
          const SizedBox(height: 8),
          if (!a.rodando && a.fase != Fase.pronto)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.system_update),
              label: Text(
                  a.temPontoSalvo ? 'Continuar download' : 'Atualizar agora'),
              onPressed: a.atualizar,
            ),
        ],
        if (a.fase == Fase.baixando || a.fase == Fase.semConexao) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: pct),
          const SizedBox(height: 8),
          if (a.fase == Fase.baixando)
            Text(pct == null
                // servidor não informou o tamanho: só o que já veio
                ? 'Baixando… ${_mb(a.recebidos)} MB'
                : 'Baixando… ${(pct * 100).floor()}% '
                    '(${_mb(a.recebidos)} de ${_mb(a.total)} MB)'),
          if (a.fase == Fase.semConexao)
            Text('Sem conexão: tentando de novo em ${a.tentarEm}s. '
                'O download continua de onde parou '
                '(${_mb(a.recebidos)} de ${_mb(a.total)} MB).'),
        ],
        if (a.fase == Fase.conferindo) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Conferindo a integridade do arquivo…'),
        ],
        if (a.rodando && a.fase != Fase.pronto)
          TextButton.icon(
            icon: const Icon(Icons.close),
            label: const Text('Cancelar'),
            onPressed: a.cancelar,
          ),
        if (a.fase == Fase.pronto) ...[
          const SizedBox(height: 16),
          const Text('Download concluído e conferido ✔'),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.install_mobile),
            label: const Text('Instalar'),
            onPressed: a.instalar,
          ),
        ],
        if (a.aviso != null) ...[
          const SizedBox(height: 8),
          Text(a.aviso!),
        ],
        if (a.fase == Fase.erro) ...[
          const SizedBox(height: 16),
          Text(a.erro!, style: TextStyle(color: tema.colorScheme.error)),
        ],
      ]),
    );
  }
}
