/// Mirrors a row in `public.profiles`.
class Profile {
  final String id;
  final String name;
  final String? mobile;
  final String role;
  final String? shgId;
  final String? village;
  final String? avatarColor;
  // Admin-only writable (migration 0083) — once false, the 4 RLS identity
  // helpers (current_role/current_shg_id/is_staff/is_leader_or_staff) every
  // policy in this schema keys off resolve to null/false for this account,
  // server-side, regardless of what the client does. `AppState.
  // accountDeactivated` uses this to force a sign-out on the client too,
  // rather than leaving the account able to keep calling an app that the
  // backend now silently rejects almost everything from.
  final bool isActive;
  final DateTime? deactivatedAt;

  const Profile({
    required this.id,
    required this.name,
    this.mobile,
    required this.role,
    this.shgId,
    this.village,
    this.avatarColor,
    this.isActive = true,
    this.deactivatedAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        name: map['name'] as String,
        mobile: map['mobile'] as String?,
        role: map['role'] as String? ?? 'member',
        shgId: map['shg_id'] as String?,
        village: map['village'] as String?,
        avatarColor: map['avatar_color'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        deactivatedAt: map['deactivated_at'] != null ? DateTime.parse(map['deactivated_at'] as String) : null,
      );

  Profile copyWith({String? role, String? shgId}) => Profile(
        id: id,
        name: name,
        mobile: mobile,
        role: role ?? this.role,
        shgId: shgId ?? this.shgId,
        village: village,
        avatarColor: avatarColor,
        isActive: isActive,
        deactivatedAt: deactivatedAt,
      );
}

/// A row from the `shg_directory` view — the safe subset of `public.shgs`
/// columns exposed for onboarding search (no bank details).
class ShgSearchResult {
  final String id;
  final String name;
  final String village;
  final String mandal;
  final String district;
  final String? grade;

  const ShgSearchResult({
    required this.id,
    required this.name,
    required this.village,
    required this.mandal,
    required this.district,
    this.grade,
  });

  factory ShgSearchResult.fromMap(Map<String, dynamic> map) => ShgSearchResult(
        id: map['id'] as String,
        name: map['name'] as String,
        village: map['village'] as String? ?? '',
        mandal: map['mandal'] as String? ?? '',
        district: map['district'] as String? ?? '',
        grade: map['grade'] as String?,
      );
}
