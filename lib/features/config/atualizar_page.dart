import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import '../../core/ambiente.dart';
import '../../core/atualizacao.dart';

typedef VerificarVersao = Future<Release> Function();
typedef BaixarEInstalar = Stream<OtaEvent> Function(Release r);

Stream<OtaEvent> baixarComOta(Release r) => OtaUpdate().execute(r.apk,
    destinationFilename: 'mesquevem.apk', sha256checksum: r.sha256);

/// Verifica a última release no GitHub e, se for mais nova, baixa o APK e
/// abre o instalador do Android (que pede a confirmação do usuário).
class AtualizarPage extends StatefulWidget {
  final VerificarVersao verificar;
  final BaixarEInstalar baixar;
  final int atual;
  final String versao;
  const AtualizarPage(
      {this.verificar = ultimaRelease,
      this.baixar = baixarComOta,
      this.atual = buildAtual,
      this.versao = versaoAtual,
      super.key});

  @override
  State<AtualizarPage> createState() => _AtualizarPageState();
}

class _AtualizarPageState extends State<AtualizarPage> {
  bool _ocupado = false;
  Release? _release;
  String? _erro, _status;
  double? _progresso;

  Future<void> _verificar() async {
    setState(() {
      _ocupado = true;
      _erro = _status = null;
      _release = null;
    });
    try {
      final r = await widget.verificar();
      if (mounted) setState(() => _release = r);
    } catch (e) {
      if (mounted) setState(() => _erro = mensagem(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _atualizar(Release r) {
    setState(() {
      _ocupado = true;
      _erro = null;
      _status = 'Baixando…';
      _progresso = 0;
    });
    widget.baixar(r).listen((e) {
      if (!mounted) return;
      setState(() {
        switch (e.status) {
          case OtaStatus.DOWNLOADING:
            _progresso = (double.tryParse(e.value ?? '') ?? 0) / 100;
            _status = 'Baixando… ${e.value ?? 0}%';
          case OtaStatus.INSTALLING:
            _progresso = null;
            _ocupado = false;
            _status = 'Abrindo o instalador: toque em "Atualizar" para '
                'concluir.';
          case OtaStatus.INSTALLATION_DONE:
            _ocupado = false;
            _status = 'Atualizado!';
          default:
            _ocupado = false;
            _progresso = null;
            _status = null;
            _erro = switch (e.status) {
              OtaStatus.PERMISSION_NOT_GRANTED_ERROR =>
                'Permita "instalar apps desta fonte" para o Mês que Vem e '
                    'tente de novo.',
              OtaStatus.DOWNLOAD_ERROR =>
                'Falha no download. Verifique a internet e tente de novo.',
              OtaStatus.CHECKSUM_ERROR =>
                'O arquivo baixado veio corrompido. Tente de novo.',
              OtaStatus.ALREADY_RUNNING_ERROR =>
                'Já há um download em andamento.',
              OtaStatus.CANCELED => 'Download cancelado.',
              _ => 'Não foi possível atualizar (${e.value ?? e.status.name}).',
            };
        }
      });
    }, onError: (Object e) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _progresso = null;
          _status = null;
          _erro = 'Não foi possível atualizar (${mensagem(e)}).';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _release;
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Atualizar')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.atual > 0
            ? 'Versão instalada: v${widget.versao}'
            : 'Versão de desenvolvimento'),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Verificar atualização'),
          onPressed: _ocupado ? null : _verificar,
        ),
        const SizedBox(height: 16),
        if (r != null && !temNova(r, atual: widget.atual))
          Text(widget.atual > 0
              ? 'Você já está na última versão 🎉'
              : 'A última versão publicada é ${r.tag}; instale pelo GitHub.'),
        if (r != null && temNova(r, atual: widget.atual)) ...[
          Text('Nova versão ${r.tag} disponível!',
              style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
              'Seus dados continuam no app. Se quiser, faça um backup antes '
              '(Config → Backup e compartilhamento).',
              style: tema.textTheme.bodySmall),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.system_update),
            label: const Text('Atualizar agora'),
            onPressed: _ocupado ? null : () => _atualizar(r),
          ),
        ],
        if (_status != null) ...[
          const SizedBox(height: 16),
          if (_progresso != null) LinearProgressIndicator(value: _progresso),
          const SizedBox(height: 8),
          Text(_status!),
        ],
        if (_erro != null) ...[
          const SizedBox(height: 16),
          Text(_erro!, style: TextStyle(color: tema.colorScheme.error)),
        ],
      ]),
    );
  }
}
