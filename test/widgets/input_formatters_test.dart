import 'package:flutter/widgets.dart';
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

    test('truncates more than 2 decimal places rather than accepting them', () {
      expect(apply('99.5012345').text, isNot(matches(RegExp(r'\.\d{3,}'))), reason: 'no more than 2 digits should ever follow the decimal point');
    });

    test('handles an empty string without throwing', () {
      expect(() => apply(''), returnsNormally);
      expect(apply('').text, '');
    });

    test('rejects an invalid keystroke without truncating prior valid input', () {
      // Regression: a plain FilteringTextInputFormatter.allow() with an
      // anchored (^) pattern only ever matches once at the start of the
      // string, so everything after the first match gets silently dropped
      // rather than just the offending character — e.g. typing a second "."
      // into "99.5" would previously collapse the field down to "99" instead
      // of leaving "99.5" untouched.
      final formatter = decimalAmountInputFormatters.single;
      const oldValue = TextEditingValue(text: '99.5', selection: TextSelection.collapsed(offset: 4));
      const newValue = TextEditingValue(text: '99.5.', selection: TextSelection.collapsed(offset: 5));
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '99.5');
    });

    test('rejects a third decimal digit without truncating to the whole-number part', () {
      final formatter = decimalAmountInputFormatters.single;
      const oldValue = TextEditingValue(text: '12.34', selection: TextSelection.collapsed(offset: 5));
      const newValue = TextEditingValue(text: '12.345', selection: TextSelection.collapsed(offset: 6));
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '12.34');
    });
  });

  group('OtpBoxFormatter', () {
    // Regression: a plain `maxLength: 1` field silently truncates a pasted
    // multi-digit code (e.g. copied whole from an SMS) down to its first
    // character. This formatter should still show only 1 digit in the box
    // that received the paste, but distribute the rest across the following
    // boxes (verified via the controllers it was given).
    late List<TextEditingController> controllers;
    late List<FocusNode> focusNodes;
    late int filledCount;

    setUp(() {
      controllers = List.generate(6, (_) => TextEditingController());
      focusNodes = List.generate(6, (_) => FocusNode());
      filledCount = 0;
    });

    tearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
      for (final f in focusNodes) {
        f.dispose();
      }
    });

    test('a single typed digit passes through untouched', () {
      final formatter = OtpBoxFormatter(index: 0, controllers: controllers, focusNodes: focusNodes, onFilled: () => filledCount++);
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '7', selection: TextSelection.collapsed(offset: 1));
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '7');
    });

    test('pasting a full code into the first box only shows its own first digit', () {
      final formatter = OtpBoxFormatter(index: 0, controllers: controllers, focusNodes: focusNodes, onFilled: () => filledCount++);
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '123456', selection: TextSelection.collapsed(offset: 6));
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '1', reason: 'this box must still show exactly 1 character, not the whole pasted string');
    });

    test('pasting a full code distributes the remaining digits to the following boxes', () async {
      final formatter = OtpBoxFormatter(index: 0, controllers: controllers, focusNodes: focusNodes, onFilled: () => filledCount++);
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '123456', selection: TextSelection.collapsed(offset: 6));
      formatter.formatEditUpdate(oldValue, newValue);
      // The distribution runs in a microtask, after formatEditUpdate returns.
      await Future.microtask(() {});

      expect(controllers.map((c) => c.text).toList(), ['1', '2', '3', '4', '5', '6']);
      expect(filledCount, 1);
    });

    test('a paste that starts mid-row only fills up to the last box, without index overflow', () async {
      final formatter = OtpBoxFormatter(index: 4, controllers: controllers, focusNodes: focusNodes, onFilled: () => filledCount++);
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '89', selection: TextSelection.collapsed(offset: 2));
      expect(() => formatter.formatEditUpdate(oldValue, newValue), returnsNormally);
      await Future.microtask(() {});

      expect(controllers[4].text, '8');
      expect(controllers[5].text, '9');
    });

    test('non-digit characters in a paste are stripped before distribution', () {
      final formatter = OtpBoxFormatter(index: 0, controllers: controllers, focusNodes: focusNodes, onFilled: () => filledCount++);
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '12-34', selection: TextSelection.collapsed(offset: 5));
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '1');
    });
  });
}
