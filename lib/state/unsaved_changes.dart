/// Global "does the currently-open full-page form have unsaved input" flag.
///
/// This exists because Flutter's normal interception widget for this class
/// of bug, `PopScope`, does not work in this app: every navigation here
/// goes through `context.go()` — a full page-stack replace — instead of
/// `context.push()` / `Navigator.pop()` (see `page_header.dart`'s own
/// Back-button comment, and `DEVELOPMENT_PROGRESS.md` round 16). Verified
/// live in a running build: with `PopScope` attached to a form page,
/// tapping the bottom nav, tapping `PageHeader`'s own Back arrow, AND
/// clicking the browser's real Back button all silently discarded typed
/// text with zero interception — none of the three ever calls
/// `Navigator.pop()`, so `PopScope`'s `onPopInvokedWithResult` never fires.
/// go_router resolves a URL change (however it happens) directly into a
/// brand-new page list rather than popping the existing one.
///
/// So instead, a full-page form sets this flag directly while it has
/// unsaved input, and the two shared navigation entry points that can
/// discard it — `PageHeader`'s Back button and the bottom nav's tap
/// handler, in `app_shell.dart` — check it first and prompt to confirm
/// before calling `context.go()`. This covers two of this app's three real
/// navigation triggers (bottom-nav tap, in-app Back arrow). The third —
/// the browser/OS Back button itself — is a known, currently-unclosed gap:
/// reliably intercepting a raw browser `popstate` before go_router acts on
/// it needs low-level JS/history interop this codebase doesn't use
/// anywhere else, a materially bigger and riskier change than this flag,
/// left for a future round rather than faked here.
class UnsavedChanges {
  UnsavedChanges._();

  /// Set by a form page's field `onChanged`/`onSelected` once the user has
  /// actually typed or picked something; cleared in that page's `dispose()`
  /// so it never leaks onto a different page.
  static bool dirty = false;
}
