import 'package:flutter/material.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../repositories/financial_repository.dart';
import '../../widgets/input_formatters.dart';

/// Returns `true` if an entry was added, so the caller can refresh its list.
Future<bool?> showFinancialEntryDialog(
  BuildContext context,
  FinancialRepository repo, {
  required String? shgId,
  required String? createdBy,
  required String entryType,
}) {
  const maxAmount = 1000000;
  final descController = TextEditingController();
  final amountController = TextEditingController();
  var isCredit = true;
  String? error;
  var submitting = false;

  return showDialog<bool>(
    context: context,
    // See shg_home_page.dart's identical fix for why: an accidental tap
    // just outside the dialog card otherwise silently discards the
    // description/amount typed so far, indistinguishable from a real save
    // failing.
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.financialEntryDialogTitle),
          // Two text fields + a segmented button + potential error text can
          // overflow an `AlertDialog`'s fixed-height content area at a
          // large text-scale setting (1.3x-2x) on a short device — wrapping
          // in a scroll view lets the dialog scroll internally instead of
          // clipping/overflowing, matching CLAUDE.md's text-scale bar.
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: descController, maxLength: 200, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.financialEntryDialogDescriptionHint)),
                const SizedBox(height: 12),
                TextField(controller: amountController, keyboardType: TextInputType.number, inputFormatters: decimalAmountInputFormatters, textInputAction: TextInputAction.done, maxLength: 9, decoration: InputDecoration(prefixText: '₹', hintText: l10n.financialEntryDialogAmountHint, counterText: '')),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(l10n.financialEntryDialogCreditLabel)),
                    ButtonSegment(value: false, label: Text(l10n.financialEntryDialogDebitLabel)),
                  ],
                  selected: {isCredit},
                  onSelectionChanged: (v) => setState(() => isCredit = v.first),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  // liveRegion so a screen-reader user hears the validation
                  // error the instant it appears, not just if they happen to
                  // already be focused here — same fix as AppAsyncBuilder's
                  // error state.
                  Semantics(liveRegion: true, child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final amount = num.tryParse(amountController.text);
                      if (descController.text.trim().isEmpty) {
                        setState(() => error = l10n.financialEntryDialogDescriptionRequiredError);
                        return;
                      }
                      if (amount == null || amount <= 0) {
                        setState(() => error = l10n.financialEntryDialogInvalidAmountError);
                        return;
                      }
                      if (amount > maxAmount) {
                        setState(() => error = l10n.financialEntryDialogAmountTooLargeError);
                        return;
                      }
                      setState(() {
                        error = null;
                        submitting = true;
                      });
                      try {
                        final saved = await repo.addEntry(
                          shgId: shgId,
                          createdBy: createdBy,
                          entryType: entryType,
                          description: descController.text.trim(),
                          debit: isCredit ? 0 : amount,
                          credit: isCredit ? amount : 0,
                        );
                        if (!saved) {
                          if (context.mounted) {
                            setState(() {
                              submitting = false;
                              error = l10n.financialEntryDialogNoShgError;
                            });
                          }
                          return;
                        }
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (_) {
                        if (context.mounted) {
                          setState(() {
                            submitting = false;
                            error = l10n.financialEntryDialogSaveError;
                          });
                        }
                      }
                    },
              child: Text(submitting ? l10n.financialEntryDialogAddingButton : l10n.financialEntryDialogAddButton),
            ),
          ],
        );
      },
    ),
  );
}
