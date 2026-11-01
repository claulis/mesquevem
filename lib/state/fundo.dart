import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../core/ambiente.dart';

/// Imagem de fundo da tela principal. Fica num arquivo na pasta do app, não
/// nos dados: é do aparelho e não vai no backup.
class Fundo extends ChangeNotifier {
  final Future<Directory> Function() _pasta;
  Fundo([this._pasta = getApplicationDocumentsDirectory]);

  File? _arquivo;
  File? get arquivo => _arquivo;

  static const _prefixo = 'fundo-';

  Future<List<File>> _existentes() async => (await _pasta())
      .listSync()
      .whereType<File>()
      .where((f) => f.uri.pathSegments.last.startsWith(_prefixo))
      .toList();

  /// Sem fundo ou com falha ao ler: segue sem fundo (não impede o app).
  Future<void> carregar() async {
    try {
      final fs = await _existentes();
      _arquivo = fs.isEmpty ? null : fs.last;
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

  Future<void> remover() => doAmbiente(() async {
        for (final f in await _existentes()) {
          await f.delete();
        }
        _arquivo = null;
        notifyListeners();
      }, 'não foi possível remover a imagem');
}
