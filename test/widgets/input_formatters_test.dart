import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/widgets/input_formatters.dart';

/// Regression coverage for the numeric-field input-restriction fix — these
/// formatters exist because keyboardType alone does nothing on desktop/web,
/// letting every amount/phone/OTP field silently accept arbitrary text.
void main() {
  group('wholeNumberInputFormatters', () {
    TextEditingValue apply(String text) {
      var value = const TextEditingValue(text: '');
      for (final f in wholeNumberInputFormatters) {
        value = f.formatEditUpdate(value, TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));
      }
      return value;
    }

    test('strips letters and symbols, keeping only digits', () {
      expect(apply('abc123def').text, '123');
      expect(apply('98765-43210').text, '9876543210');
      expect(apply('₹500').text, '500');
    });

    test('leaves a pure digit string untouched', () {
      expect(apply('9876543210').text, '9876543210');
    });

    test('rejects a decimal point entirely', () {
      expect(apply('123.45').text, '12345');
    });
  });

  group('decimalAmountInputFormatters', () {
    TextEditingValue apply(String text) {
      var value = const TextEditingValue(text: '');
      for (final f in decimalAmountInputFormatters) {
        value = f.formatEditUpdate(value, TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));
      }
      return value;
    }

    test('allows a plain whole-number amount', () {
      expect(apply('1500').text, '1500');
    });

    test('allows up to 2 decimal places', () {
      expect(apply('99.50').text, '99.50');
    });

    test('rejects letters mixed into the amount', () {
      expect(apply('99a.50b').text, isNot(contains('a')));
      expect(apply('99a.50b').text, isNot(contains('b')));
    });
  });
}
