import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Restricts a field to whole numbers only — for phone numbers, OTP digits,
/// and counts (e.g. stock) where a decimal point is never valid.
final wholeNumberInputFormatters = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];

/// Restricts a field to a non-negative amount with up to 2 decimal places —
/// for currency fields (₹) where paise are a legitimate value, unlike
/// [wholeNumberInputFormatters].
///
/// A plain `FilteringTextInputFormatter.allow` with this anchored pattern
/// would delete everything *after* the first match instead of just the
/// offending character (e.g. pasting "1,234.50" would leave only "1") since
/// `allow` treats every non-matched region as invalid and strips it. This
/// formatter instead rejects the whole edit and keeps the previous value
/// whenever the result wouldn't be a valid amount.
final decimalAmountInputFormatters = <TextInputFormatter>[_DecimalAmountFormatter()];

class _DecimalAmountFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d*\.?\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty || _pattern.hasMatch(newValue.text)) return newValue;
    return oldValue;
  }
}

/// One box in a multi-box OTP entry row. A plain `maxLength: 1` field
/// silently truncates a pasted multi-digit code (e.g. copied whole from an
/// SMS) down to its first character; this formatter instead detects a
/// paste and distributes the extra digits across the following boxes.
///
/// Also handles backspace-to-previous-box navigation — previously nothing
/// moved focus backward at all (only [onChanged]'s forward-advance on a
/// digit typed in existed), so clearing a wrong digit and continuing to
/// backspace left the user stuck needing to manually tap into each earlier
/// box instead of a natural single "hold backspace" retype.
class OtpBoxFormatter extends TextInputFormatter {
  OtpBoxFormatter({required this.index, required this.controllers, required this.focusNodes, required this.onFilled});
  final int index;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback onFilled;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty && oldValue.text.isNotEmpty && index > 0) {
      // Backspace cleared this box — jump back to the previous one so
      // repeated backspace naturally walks left through the whole code,
      // instead of stalling on an empty box the moment it's reached.
      Future.microtask(() => focusNodes[index - 1].requestFocus());
    }
    if (digits.length <= 1) {
      return TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length));
    }
    Future.microtask(() {
      for (var j = 0; j < digits.length && index + j < controllers.length; j++) {
        controllers[index + j].text = digits[j];
      }
      final next = (index + digits.length).clamp(0, controllers.length - 1);
      focusNodes[next].requestFocus();
      onFilled();
    });
    return TextEditingValue(text: digits[0], selection: const TextSelection.collapsed(offset: 1));
  }
}
