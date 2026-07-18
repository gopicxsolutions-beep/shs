import 'package:flutter/services.dart';

/// Restricts a field to whole numbers only — for phone numbers, OTP digits,
/// and counts (e.g. stock) where a decimal point is never valid.
final wholeNumberInputFormatters = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];

/// Restricts a field to a non-negative amount with up to 2 decimal places —
/// for currency fields (₹) where paise are a legitimate value, unlike
/// [wholeNumberInputFormatters].
final decimalAmountInputFormatters = <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))];
