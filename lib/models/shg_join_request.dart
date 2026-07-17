/// Mirrors a row in `public.shg_join_requests` — the "Member → Select SHG →
/// Approval by Leader" workflow. A member's `profiles.shg_id` stays null
/// until their leader (or staff) approves via `approve_shg_join_request()`.
class ShgJoinRequest {
  final String id;
  final String memberId;
  final String? memberName;
  final String shgId;
  final String? shgName;
  final String status; // pending | approved | rejected
  final DateTime requestedAt;

  const ShgJoinRequest({
    required this.id,
    required this.memberId,
    this.memberName,
    required this.shgId,
    this.shgName,
    required this.status,
    required this.requestedAt,
  });

  factory ShgJoinRequest.fromMap(Map<String, dynamic> map) => ShgJoinRequest(
        id: map['id'] as String,
        memberId: map['member_id'] as String,
        memberName: (map['profiles'] as Map<String, dynamic>?)?['name'] as String?,
        shgId: map['shg_id'] as String,
        shgName: (map['shgs'] as Map<String, dynamic>?)?['name'] as String?,
        status: map['status'] as String,
        requestedAt: DateTime.parse(map['requested_at'] as String),
      );
}
