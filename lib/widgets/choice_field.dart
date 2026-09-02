import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// A single option shown by [ChoiceChipGroup]/[MultiChoiceChipGroup] — a
/// stored `value` (the code written to the database) paired with its
/// already-localized display `text`.
class ChoiceOption<T> {
  const ChoiceOption(this.value, this.text);
  final T value;
  final String text;
}

/// A labeled group of mutually-exclusive chips. Pulled out of the loan
/// tenure picker's inline `ChoiceChip` styling (see
/// lib/pages/loans/loan_apply_page.dart) since the baseline survey
/// (lib/pages/auth/profile_setup_page.dart) repeats this exact shape for
/// several dozen single-select questions — a dropdown would be slower to
/// scan/tap for 3-5 short options than chips laid out at once.
class ChoiceChipGroup<T> extends StatelessWidget {
  const ChoiceChipGroup({super.key, required this.label, required this.options, required this.value, required this.onChanged});

  final String label;
  final List<ChoiceOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final selected = o.value == value;
            return ChoiceChip(
              label: Text(o.text),
              selected: selected,
              onSelected: (_) => onChanged(o.value),
              selectedColor: Brand.c50,
              labelStyle: AppTheme.sans(12, weight: FontWeight.w600, color: selected ? Brand.c700 : Neutral.c600),
              backgroundColor: Colors.white,
              side: BorderSide(color: selected ? Brand.c500 : Neutral.c200),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Same shape as [ChoiceChipGroup] but any number of options may be
/// selected at once (e.g. "Apps Used", "Support needed") — backed by a
/// `Set<String>` of codes, matching the `text[]` columns these answers are
/// stored in (`member_baseline_surveys`, migration 0151).
class MultiChoiceChipGroup extends StatelessWidget {
  const MultiChoiceChipGroup({super.key, required this.label, required this.options, required this.values, required this.onChanged});

  final String label;
  final List<ChoiceOption<String>> options;
  final Set<String> values;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final selected = values.contains(o.value);
            return FilterChip(
              label: Text(o.text),
              selected: selected,
              onSelected: (sel) {
                final next = Set<String>.from(values);
                if (sel) {
                  next.add(o.value);
                } else {
                  next.remove(o.value);
                }
                onChanged(next);
              },
              selectedColor: Brand.c50,
              checkmarkColor: Brand.c700,
              labelStyle: AppTheme.sans(12, weight: FontWeight.w600, color: selected ? Brand.c700 : Neutral.c600),
              backgroundColor: Colors.white,
              side: BorderSide(color: selected ? Brand.c500 : Neutral.c200),
            );
          }).toList(),
        ),
      ],
    );
  }
}
