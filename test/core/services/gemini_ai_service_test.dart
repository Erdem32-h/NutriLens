import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/services/anthropic_ai_service.dart'
    show MealAnalysisResult;
import 'package:nutrilens/core/services/gemini_ai_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockAuthClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

/// A meal payload the shared parser accepts, so the only thing a test can
/// fail on is the retry/status behaviour under test.
const _validMealJson =
    '{"food_name":"Mercimek Corbasi","portion_grams":300,'
    '"nutrition":{"energy_kcal":180,"fat":4,"protein":9},'
    '"confidence":0.8,"description":"Ev yapimi"}';

/// What `functions.invoke` really does with a non-2xx reply: it throws, it
/// never returns a [FunctionResponse] carrying the error status.
FunctionException _httpError(int status, String error) =>
    FunctionException(status: status, details: {'error': error});

void main() {
  late MockSupabaseClient client;
  late MockFunctionsClient functions;
  late GeminiAiService service;
  late MockAuthClient auth;

  setUp(() {
    client = MockSupabaseClient();
    functions = MockFunctionsClient();
    auth = MockAuthClient();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentSession).thenReturn(null);
    when(() => client.functions).thenReturn(functions);
    service = GeminiAiService(client);
  });

  Future<MealAnalysisResult> analyze() =>
      service.analyzeMeal('ZmFrZQ==', deviceHash: 'device-1');

  /// Meal actions also refresh stale JWTs for signed-in callers.
  void stubInvoke(List<Future<FunctionResponse> Function()> responses) {
    var call = 0;
    when(
      () => functions.invoke(any(), body: any(named: 'body')),
    ).thenAnswer((_) => responses[call++ % responses.length]());
  }

  test('retries once when the connection drops mid-request', () async {
    // NUTRILENS-7: a reset socket arrives with no HTTP status at all. The
    // upload almost never finished, so the second attempt is the one that
    // reaches the model.
    var attempts = 0;
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer((
      _,
    ) async {
      attempts++;
      if (attempts == 1) {
        throw Exception('ClientException: Connection reset by peer');
      }
      return FunctionResponse(data: {'result': _validMealJson}, status: 200);
    });

    final result = await analyze();

    expect(attempts, 2);
    expect(result.foodName, 'Mercimek Corbasi');
  });

  test('gives up after the third dropped connection', () async {
    // Two retries, not an unbounded loop: a genuinely dead link must surface
    // as an error the user can act on rather than an endless spinner.
    var attempts = 0;
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer((
      _,
    ) async {
      attempts++;
      throw Exception('ClientException: Connection reset by peer');
    });

    await expectLater(analyze(), throwsA(isA<GeminiServiceException>()));
    expect(attempts, 3);
  });

  test('does not retry a rate-limited request', () async {
    // Retrying a 429 spends quota the caller already knows it does not have,
    // and the proxy maps out-of-credit to the same status.
    var attempts = 0;
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer((
      _,
    ) async {
      attempts++;
      throw _httpError(429, 'rate limited');
    });

    await expectLater(
      analyze(),
      throwsA(
        isA<GeminiServiceException>().having(
          (e) => e.statusCode,
          'status',
          429,
        ),
      ),
    );
    expect(attempts, 1);
  });

  test('public meal action refreshes a signed-in session on 401', () async {
    when(() => auth.currentSession).thenReturn(MockSession());
    when(() => auth.refreshSession()).thenAnswer((_) async => AuthResponse());
    stubInvoke([
      () async => throw _httpError(401, 'expired'),
      () async =>
          FunctionResponse(data: {'result': _validMealJson}, status: 200),
    ]);
    expect((await analyze()).foodName, 'Mercimek Corbasi');
    verify(() => auth.refreshSession()).called(1);
  });

  test('guest 401 never attempts session refresh', () async {
    stubInvoke([() async => throw _httpError(401, 'unauthorized')]);
    await expectLater(analyze(), throwsA(isA<GeminiServiceException>()));
    verifyNever(() => auth.refreshSession());
  });

  test('a server error keeps its status and is not retried as a dropped '
      'connection', () async {
    // A null status is what the screen reads as "no connection"; a 5xx that
    // lost its status would be told to check their internet.
    var attempts = 0;
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer((
      _,
    ) async {
      attempts++;
      throw _httpError(502, 'upstream failed');
    });

    await expectLater(
      analyze(),
      throwsA(
        isA<GeminiServiceException>()
            .having((e) => e.statusCode, 'status', 502)
            .having((e) => e.message, 'message', 'upstream failed'),
      ),
    );
    expect(attempts, 1);
  });

  group('content failures are not transport failures', () {
    // NUTRILENS-4 was indistinguishable from a dead socket in both Sentry and
    // the funnel because it also carried a null status.
    test('unparseable model output reports 422', () async {
      stubInvoke([
        () async =>
            FunctionResponse(data: {'result': 'sorry, no idea'}, status: 200),
      ]);

      await expectLater(
        analyze(),
        throwsA(
          isA<GeminiServiceException>().having(
            (e) => e.statusCode,
            'status',
            422,
          ),
        ),
      );
    });

    test('empty model output reports 422', () async {
      stubInvoke([
        () async => FunctionResponse(data: {'result': '   '}, status: 200),
      ]);

      await expectLater(
        analyze(),
        throwsA(
          isA<GeminiServiceException>().having(
            (e) => e.statusCode,
            'status',
            422,
          ),
        ),
      );
    });

    test('a 422 is never retried', () async {
      var attempts = 0;
      when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer((
        _,
      ) async {
        attempts++;
        return FunctionResponse(
          data: {'result': 'sorry, no idea'},
          status: 200,
        );
      });

      await expectLater(analyze(), throwsA(isA<GeminiServiceException>()));
      expect(attempts, 1);
    });
  });
}
