/// Mirrors a row in `public.shgs`.
class ShgProfile {
  final String id;
  final String name;
  final String? regNumber;
  final DateTime? formationDate;
  final String? village;
  final String? mandal;
  final String? district;
  final String? state;
  final String? bankName;
  final String? bankAccount;
  final String? ifsc;
  final String? grade;
  final String? clf;
  final String? vo;

  const ShgProfile({
    required this.id,
    required this.name,
    this.regNumber,
    this.formationDate,
    this.village,
    this.mandal,
    this.district,
    this.state,
    this.bankName,
    this.bankAccount,
    this.ifsc,
    this.grade,
    this.clf,
    this.vo,
  });

  factory ShgProfile.fromMap(Map<String, dynamic> map) => ShgProfile(
        id: map['id'] as String,
        name: map['name'] as String,
        regNumber: map['reg_number'] as String?,
        formationDate: map['formation_date'] != null ? DateTime.parse(map['formation_date'] as String) : null,
        village: map['village'] as String?,
        mandal: map['mandal'] as String?,
        district: map['district'] as String?,
        state: map['state'] as String?,
        bankName: map['bank_name'] as String?,
        bankAccount: map['bank_account'] as String?,
        ifsc: map['ifsc'] as String?,
        grade: map['grade'] as String?,
        clf: map['clf'] as String?,
        vo: map['vo'] as String?,
      );
}

/// Mirrors a row in `public.profiles`, scoped to one SHG's roster.
class Member {
  final String id;
  final String name;
  final String? mobile;
  final String role;
  final String? village;

  const Member({required this.id, required this.name, this.mobile, required this.role, this.village});

  factory Member.fromMap(Map<String, dynamic> map) => Member(
        id: map['id'] as String,
        name: map['name'] as String,
        mobile: map['mobile'] as String?,
        role: map['role'] as String? ?? 'member',
        village: map['village'] as String?,
      );
}

/// Mirrors a row in `public.shg_documents`.
class ShgDocument {
  final String id;
  final String name;
  final String? type;
  final String? size;
  final String? storagePath;
  final DateTime createdAt;

  const ShgDocument({required this.id, required this.name, this.type, this.size, this.storagePath, required this.createdAt});

  factory ShgDocument.fromMap(Map<String, dynamic> map) => ShgDocument(
        id: map['id'] as String,
        name: map['name'] as String,
        type: map['type'] as String?,
        size: map['size'] as String?,
        storagePath: map['storage_path'] as String?,
        // `created_at` is `timestamptz` (UTC). Convert to local (IST) here
        // so `shg_documents_page.dart`'s date-only `DateFormat` never shows
        // the wrong calendar day for a document uploaded near local midnight.
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}
