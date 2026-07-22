import 'dart:async';
import 'package:http/http.dart' as http;

/// An [http.Client] wrapper that bounds every request to [timeout].
///
/// Passed once to `Supabase.initialize(httpClient: ...)` in `main.dart`, so
/// it transparently covers every Supabase sub-client built on `package:http`
/// (Postgrest reads/writes, Auth, Storage, and Edge Function invocations —
/// see `SupabaseClient._init` in the `supabase` package, which threads the
/// same `httpClient` through `rest`/`functions`/`storage`/`auth`).
///
/// Without this, a request made on this app's target rural/unreliable
/// mobile connections that never gets a response (dropped connection,
/// captive portal, silently black-holed request) hangs forever — there is
/// no other client-side timeout anywhere in this app, so a Submit button's
/// busy-state would spin indefinitely with no feedback and no way to
/// retry. [timeout] fires a [TimeoutException], which `AppAsyncBuilder`
/// (`lib/widgets/async_state.dart`) already recognizes as a network error
/// and repository callers' existing `catch` blocks handle the same way as
/// any other failed write.
///
/// 30 seconds is chosen to comfortably exceed a normal request over a slow
/// 2G/3G connection (this app's payloads are small JSON, not large file
/// uploads) while still giving the user feedback well short of the
/// multi-minute hangs some OS/browser defaults allow.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient({http.Client? inner, this.timeout = const Duration(seconds: 30)}) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException('Request to ${request.url} timed out after ${timeout.inSeconds}s', timeout);
      },
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
