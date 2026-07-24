import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shg_saathi/services/timeout_http_client.dart';

void main() {
  group('TimeoutHttpClient', () {
    test('lets a response that arrives within the timeout through unaffected', () async {
      final inner = http_testing.MockClient((request) async {
        return http.Response('ok', 200);
      });
      final client = TimeoutHttpClient(inner: inner, timeout: const Duration(milliseconds: 200));

      final response = await client.get(Uri.parse('https://example.com'));

      expect(response.statusCode, 200);
      expect(response.body, 'ok');
    });

    test('throws a TimeoutException instead of hanging when the connection never responds', () async {
      final inner = http_testing.MockClient((request) async {
        // Simulates a request that never gets a response — the exact
        // shape of a dropped connection / black-holed request on a
        // genuinely bad rural mobile connection, with no server-side
        // error to catch.
        return Future<http.Response>.delayed(const Duration(seconds: 5), () => http.Response('too late', 200));
      });
      final client = TimeoutHttpClient(inner: inner, timeout: const Duration(milliseconds: 50));

      await expectLater(client.get(Uri.parse('https://example.com')), throwsA(isA<TimeoutException>()));
    });
  });
}
