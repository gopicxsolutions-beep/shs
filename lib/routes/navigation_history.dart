/// Tracks genuine, user-visible navigation across the app's flat
/// `context.go()`-based routing. Per this project's own architecture rule
/// (CLAUDE.md: "Navigation is context.go() everywhere. Never push()/pop()")
/// every route is a sibling reached via a full stack REPLACE, not a push —
/// so Flutter's own `Navigator` stack is almost always exactly one page
/// deep, meaning `Navigator.of(context).canPop()` is essentially always
/// false. `PageHeader`'s Back button used to rely on exactly that check,
/// so tapping Back from nearly any sub-page silently fell through to its
/// "nothing to pop" fallback (`context.go(Paths.dashboard)`) instead of
/// returning to wherever the user actually came from — a real, reported
/// bug ("back button navigates to Home instead of the previous page"), not
/// a hypothetical one.
///
/// This is a lightweight, app-wide substitute: `router.dart`'s own
/// `redirect` callback (which genuinely runs on every settled navigation,
/// not just on push/pop) records each distinct resolved location here via
/// [recordVisit]; `PageHeader`'s Back button then calls [popToPrevious] to
/// find the previous distinct location and `go()`es there directly instead
/// of asking the Navigator (which has nothing useful to say).
class NavigationHistory {
  NavigationHistory._();

  static final List<String> _stack = [];

  /// Called from `router.dart`'s `redirect` for the final resolved location
  /// of every navigation. A no-op if it matches the current top of the
  /// stack — `redirect` can re-evaluate the same settled location more than
  /// once (e.g. on an unrelated `AppState.notifyListeners()` call, since
  /// `refreshListenable: appState` re-runs `redirect` against whatever the
  /// CURRENT `matchedLocation` already is), and without this dedup those
  /// re-evaluations would each push a duplicate entry, making every second
  /// Back tap look like a no-op (landing back on the same page).
  static void recordVisit(String location) {
    if (_stack.isNotEmpty && _stack.last == location) return;
    _stack.add(location);
  }

  /// Pops the current (topmost) location — presumed to be wherever the user
  /// is right now, since it was the most recently recorded visit — and
  /// returns whatever's now on top: the previous distinct page actually
  /// visited, or `null` if there isn't one (a fresh app launch/deep link
  /// with no prior history, or every earlier entry was this same location).
  /// `null` means the caller should fall back to its own default
  /// destination (`PageHeader` falls back to the dashboard, matching the
  /// bottom nav's Home tab).
  static String? popToPrevious() {
    if (_stack.isNotEmpty) _stack.removeLast();
    return _stack.isNotEmpty ? _stack.last : null;
  }

  /// Test-only — each widget test boots a fresh `MaterialApp`, but this is
  /// process-wide static state that would otherwise leak Back-navigation
  /// history from one test into the next.
  static void resetForTest() => _stack.clear();
}
