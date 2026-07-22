import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';

/// Shared "unsaved changes" confirmation, for full-page forms that raise a
/// `_dirty` flag once the user has actually typed/selected something. Every
/// navigation in this app is a `context.go()` full-page-stack replace (see
/// `page_header.dart`'s Back-button comment), so without this, a user who
/// fills in a multi-field form and then taps Back/Home/bottom-nav loses
/// everything typed with zero warning — a real, common scenario on the slow
/// rural connections this app targets, where getting distracted mid-form is
/// routine. Matches this app's existing confirm-dialog style (see the
/// "Delete scheme?" dialog in `admin_schemes_page.dart`): plain `TextButton`
/// for the safe/cancel choice, plain `FilledButton` for the action that
/// proceeds.
///
/// Returns `true` only if the user explicitly chose to discard.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  // Nullable, not `!`: this dialog is reachable from PageHeader's Back
  // button on nearly every form page, including older widget tests that
  // pump a bare `MaterialApp` with no localization delegates configured —
  // fall back to English rather than crash their build in that case; a
  // real app boot always has the delegates via MaterialApp.router.
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.discardChangesTitle ?? 'Discard changes?'),
      content: Text(l10n?.discardChangesMessage ?? "You've entered information on this page that hasn't been saved yet. Leaving now will lose it."),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n?.discardChangesKeepEditing ?? 'Keep Editing')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n?.discardChangesDiscard ?? 'Discard')),
      ],
    ),
  );
  return result == true;
}
