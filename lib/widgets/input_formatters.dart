import 'package:flutter/services.dart';

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
