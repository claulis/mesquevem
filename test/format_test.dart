import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:compras/core/ambiente.dart';
import 'package:compras/core/erros.dart';
import 'package:compras/core/format.dart';

Matcher recusa(String mensagem) => throwsA(isA<FormatException>()
    .having((e) => e.message, 'message', contains(mensagem)));

void main() {
  test('lerValor aceita pt-BR e ponto decimal', () {
    for (final (texto, valor) in [
      ('12', 12.0),
      ('12,5', 12.5),
      ('12,50', 12.5),
      ('12.5', 12.5),
      ('12.50', 12.5),
      ('1.234,56', 1234.56),
      ('1.234.567,8', 1234567.8),
      ('1.234.567', 1234567.0),
      ('1,234.56', 1234.56), // padrão americano: último separador é o decimal
      ('1,234,567.89', 1234567.89),
      ('1,000,000', 1000000.0), // simétrico a 1.000.000
      ('R\$ 10', 10.0),
      (' R\$ 1.000,00 ', 1000.0),
      ('0,01', 0.01),
      ('12,', 12.0),
      (',5', 0.5),
      ('.5', 0.5),
    ]) {
      expect(lerValor(texto), valor, reason: texto);
    }
  });

  test('lerValor recusa ambíguos com mensagem própria', () {
    for (final t in ['1.250', '1.000', '12.345', '1,250', '1,000', '123,456']) {
      expect(() => lerValor(t), recusa('Ambíguo'), reason: t);
    }
  });

  test('lerValor recusa mais de 2 casas decimais', () {
    for (final t in ['0,125', '0.125', '1,2345', '1.234,567', '1234,567']) {
      expect(() => lerValor(t), recusa('2 casas'), reason: t);
    }
  });

  test('lerValor recusa zero, vazio, lixo, NaN e infinitos', () {
    expect(() => lerValor(''), recusa('Informe o valor'));
    expect(() => lerValor('  '), recusa('Informe o valor'));
    expect(() => lerValor(r'R$'), recusa('Informe o valor'));
    // espaço ou "R$" no meio não são ignorados (não pode virar 1250 ou 12)
    for (final t in ['12 50', '1 234,56', r'1R$2', r'12R$']) {
      expect(() => lerValor(t), recusa('Use só números'), reason: t);
    }
    expect(() => lerValor('0'), recusa('maior que zero'));
    expect(() => lerValor('0,00'), recusa('maior que zero'));
    expect(() => lerValor('9' * 400), recusa('grande demais'));
    expect(() => lerValor('1${'0' * 21}'), recusa('grande demais'));
    expect(() => lerValor('1.000.000.000.000,01'), recusa('grande demais'));
    expect(lerValor('1.000.000.000.000'), valorMaximo);
    for (final t in ['abc', 'NaN', 'Infinity', '-5', '1e5', '1e999']) {
      expect(() => lerValor(t), recusa('Use só números'), reason: t);
    }
    for (final t in [
      ',',
      '.',
      '1,2,3',
      '1..2',
      '1.234.56',
      '1,234,56',
      '12.34.567,8',
      '1.2.3,45',
      '1,23,456.7'
    ]) {
      expect(() => lerValor(t), throwsFormatException, reason: t);
    }
  });

  test('mensagem tira prefixos técnicos', () {
    expect(mensagem(const FormatException('x')), 'x');
    expect(mensagem(const ErroDoApp('y')), 'y');
    expect(mensagem(PlatformException(code: 'c', message: 'disco cheio')),
        'disco cheio');
    expect(mensagem(PlatformException(code: 'c')), 'c');
  });

  test('doAmbiente: Exception vira ErroDoApp legível; Error passa', () async {
    await expectLater(
        doAmbiente(() async => throw PlatformException(code: 'c', message: 'm'),
            'falhou'),
        throwsA(
            isA<ErroDoApp>().having((e) => e.motivo, 'motivo', 'falhou (m)')));
    await expectLater(doAmbiente(() async => throw StateError('bug'), 'falhou'),
        throwsStateError);
  });

  test('valores com ponto de milhar', () {
    expect(fmtNumero(999), '999,00');
    expect(fmtNumero(1234.5), '1.234,50');
    expect(fmtNumero(1000000), '1.000.000,00');
    expect(fmtNumero(-1234.5), '-1.234,50');
    expect(fmtValor(1000), 'R\$ 1.000,00');
  });

  test('o que fmtNumero escreve, lerValor lê de volta', () {
    for (final v in <double>[
      0.01,
      12.5,
      999.99,
      1000,
      1234.56,
      1000000,
      987654321.09
    ]) {
      expect(lerValor(fmtNumero(v)), v, reason: fmtNumero(v));
    }
  });
}
