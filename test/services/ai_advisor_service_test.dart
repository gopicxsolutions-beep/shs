import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/services/ai_advisor_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regression coverage for the actual FunctionException -> distinguishable
/// AiAdvisorRequestException translation done by
/// mapFunctionExceptionToAdvisorException (extracted out of
/// EdgeFunctionAiAdvisorService.ask so it's unit-testable without a live
/// Supabase Functions client — supabase_flutter's FunctionsClient.invoke
/// throws FunctionException(status, details, reasonPhrase) for every
/// non-2xx ai-advisor-proxy response, with `details` being the decoded JSON
/// error body `{ok: false, error: <reason>}` — see
/// supabase/functions/ai-advisor-proxy/index.ts's HttpError handling).
void main() {
  test('a 400 moderation/validation rejection carries the exact server reason and status through', () {
    const reason =
        "This looks like it may be about self-harm. This assistant can't help with that — please reach out to someone you trust, your SHG leader, or a local helpline right away.";
    final e = FunctionException(status: 400, details: {'ok': false, 'error': reason}, reasonPhrase: 'Bad Request');

    final mapped = mapFunctionExceptionToAdvisorException(e);

    expect(mapped.statusCode, 400);
    expect(mapped.reason, reason);
  });

  test('a 429 rate-limit rejection carries the exact server reason and status through', () {
    const reason = 'Too many requests. Please wait a minute before asking again.';
    final e = FunctionException(status: 429, details: {'ok': false, 'error': reason});

    final mapped = mapFunctionExceptionToAdvisorException(e);

    expect(mapped.statusCode, 429);
    expect(mapped.reason, reason);
  });

  test('a 401 unidentified-caller failure carries its status and reason through unchanged', () {
    final e = FunctionException(status: 401, details: {'ok': false, 'error': 'Could not identify the authenticated caller.'});

    final mapped = mapFunctionExceptionToAdvisorException(e);

    expect(mapped.statusCode, 401);
    expect(mapped.reason, 'Could not identify the authenticated caller.');
  });

  test('a 502 upstream-provider failure carries its status and reason through unchanged', () {
    final e = FunctionException(status: 502, details: {'ok': false, 'error': 'The advisor service is temporarily unavailable. Please try again.'});

    final mapped = mapFunctionExceptionToAdvisorException(e);

    expect(mapped.statusCode, 502);
    expect(mapped.reason, 'The advisor service is temporarily unavailable. Please try again.');
  });

  test('a body that is not JSON (details is a raw String, not a Map) falls back to the HTTP reason phrase', () {
    final e = FunctionException(status: 503, details: '<html>Service Unavailable</html>', reasonPhrase: 'Service Unavailable');

    final mapped = mapFunctionExceptionToAdvisorException(e);

    expect(mapped.statusCode, 503);
    expect(mapped.reason, 'Service Unavailable');
  });

  test('no usable reason anywhere falls back to a fixed generic string rather than throwing', () {
    final e = FunctionException(status: 500, details: {'ok': false});

    final mapped = mapFunctionExceptionToAdvisorException(e);

    expect(mapped.statusCode, 500);
    expect(mapped.reason, 'AI advisor request failed');
  });
}
