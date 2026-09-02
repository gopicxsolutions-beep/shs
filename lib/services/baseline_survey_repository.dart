import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/baseline_survey.dart';
import 'supabase_service.dart';

/// Backed by `public.member_baseline_surveys` (migration 0151). Live mode
/// only — like `ProfileRepository`, this class assumes a real Supabase
/// session; demo mode never calls it (see `AppState.needsBaselineSurvey`
/// and `AppState.submitBaselineSurvey`, which branch on
/// `SupabaseService.isConfigured` before ever constructing a repository
/// call, the same way `AppState.completeProfileSetup` already does for
/// `ProfileRepository`).
class BaselineSurveyRepository {
  SupabaseClient get _client => SupabaseService.instance.client;

  /// Whether the current session's profile has already submitted the
  /// survey. A lightweight existence check (not a full row select) since
  /// the app never needs to redisplay a submitted answer, only gate
  /// dashboard access on it (see the router's `needsBaselineSurvey`
  /// redirect).
  Future<bool> hasSubmitted(String profileId) async {
    final row = await _client.from('member_baseline_surveys').select('profile_id').eq('profile_id', profileId).maybeSingle();
    return row != null;
  }

  /// Upsert, not a plain insert: `member_baseline_surveys_insert_own` and
  /// `_update_own` (migration 0151) both key off `profile_id = auth.uid()`,
  /// so this is safe to call again if an earlier submit attempt failed
  /// partway (e.g. a dropped connection right after `profiles` was
  /// upserted but before this call completed) without erroring on a
  /// duplicate-key conflict.
  Future<void> submit(BaselineSurveyDraft draft) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('member_baseline_surveys').upsert({
      'profile_id': uid,
      ...draft.toMap(),
    });
  }
}
