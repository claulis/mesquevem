import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ambiente.dart';

/// Imagem de fundo da tela principal. Fica num arquivo na pasta do app, não
/// nos dados: é do aparelho e não vai no backup.
class Fundo extends ChangeNotifier {
  final Future<Directory> Function() _pasta;
  Fundo([this._pasta = getApplicationDocumentsDirectory]);

  File? _arquivo;
  File? get arquivo => _arquivo;

  /// Opacidade da imagem na tela principal (0,05 a 1). Baixa deixa o texto
  /// legível; o usuário escolhe em Personalização do fundo.
  double opacidade = opacidadePadrao;
  static const opacidadePadrao = 0.3, _chaveOpacidade = 'fundo_opacidade';

  static const _prefixo = 'fundo-';

  /// Ordenados do mais antigo ao mais novo: o nome leva o horário em
  /// milissegundos (13 dígitos), e a ordem do listSync não é garantida.
  Future<List<File>> _existentes() async => (await _pasta())
      .listSync()
      .whereType<File>()
      .where((f) => f.uri.pathSegments.last.startsWith(_prefixo))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  /// Sem fundo ou com falha ao ler: segue sem fundo (não impede o app).
  Future<void> carregar() async {
    try {
      final fs = await _existentes();
      _arquivo = fs.isEmpty ? null : fs.last;
      opacidade =
          (await SharedPreferences.getInstance()).getDouble(_chaveOpacidade) ??
              opacidadePadrao;
      notifyListeners();
    } on Exception {
      // sem fundo
    }
  }

  /// Nome novo a cada troca: o cache de imagens do Flutter é por caminho.
  Future<void> definir(List<int> bytes) => doAmbiente(() async {
        final antigos = await _existentes();
        final novo = File('${(await _pasta()).path}/$_prefixo'
            '${DateTime.now().millisecondsSinceEpoch}');
        await novo.writeAsBytes(bytes, flush: true);
        for (final f in antigos) {
          await f.delete();
        }
        _arquivo = novo;
        notifyListeners();
      }, 'não foi possível gravar a imagem');

  /// Muda na hora (a tela acompanha o controle deslizante) e grava.
  Future<void> definirOpacidade(double valor) async {
    opacidade = valor.clamp(0.05, 1.0);
    notifyListeners();
    await doAmbiente(
        () async => (await SharedPreferences.getInstance())
            .setDouble(_chaveOpacidade, opacidade),
        'não foi possível gravar a opacidade');
  }

  Future<void> remover() => doAmbiente(() async {
        for (final f in await _existentes()) {
          await f.delete();
        }
        _arquivo = null;
        notifyListeners();
      }, 'não foi possível remover a imagem');
}
