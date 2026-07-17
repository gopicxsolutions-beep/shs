/// Mirrors a row in `public.profiles`.
class Profile {
  final String id;
  final String name;
  final String? mobile;
  final String role;
  final String? shgId;
  final String? village;
  final String? avatarColor;

  const Profile({
    required this.id,
    required this.name,
    this.mobile,
    required this.role,
    this.shgId,
    this.village,
    this.avatarColor,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        name: map['name'] as String,
        mobile: map['mobile'] as String?,
        role: map['role'] as String? ?? 'member',
        shgId: map['shg_id'] as String?,
        village: map['village'] as String?,
        avatarColor: map['avatar_color'] as String?,
      );

  Profile copyWith({String? role, String? shgId}) => Profile(
        id: id,
        name: name,
        mobile: mobile,
        role: role ?? this.role,
        shgId: shgId ?? this.shgId,
        village: village,
        avatarColor: avatarColor,
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
