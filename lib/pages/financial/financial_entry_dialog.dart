import 'package:flutter/material.dart';
import '../../repositories/financial_repository.dart';

/// Returns `true` if an entry was added, so the caller can refresh its list.
Future<bool?> showFinancialEntryDialog(
  BuildContext context,
  FinancialRepository repo, {
  required String? shgId,
  required String? createdBy,
  required String entryType,
}) {
  final descController = TextEditingController();
  final amountController = TextEditingController();
  var isCredit = true;

  return showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: descController, decoration: const InputDecoration(hintText: 'Description')),
            const SizedBox(height: 12),
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: '₹', hintText: 'Amount')),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Credit (in)')),
                ButtonSegment(value: false, label: Text('Debit (out)')),
              ],
              selected: {isCredit},
              onSelectionChanged: (v) => setState(() => isCredit = v.first),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = num.tryParse(amountController.text);
              if (descController.text.trim().isEmpty || amount == null || amount <= 0) return;
              await repo.addEntry(
                shgId: shgId,
                createdBy: createdBy,
                entryType: entryType,
                description: descController.text.trim(),
                debit: isCredit ? 0 : amount,
                credit: isCredit ? amount : 0,
              );
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}
