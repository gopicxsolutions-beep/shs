enum Role { member, leader, crp, clf, admin }

class RoleInfo {
  final Role id;
  final String label;
  final String shortLabel;
  final String description;
  const RoleInfo(this.id, this.label, this.shortLabel, this.description);
}

const roles = <RoleInfo>[
  RoleInfo(Role.member, 'SHG Member', 'Member', 'Savings, loans, attendance & schemes'),
  RoleInfo(Role.leader, 'SHG Leader / President', 'Leader', 'Manage members, meetings & approvals'),
  RoleInfo(Role.crp, 'Community Resource Person', 'CRP', 'Monitor SHGs & training'),
  RoleInfo(Role.clf, 'Cluster Level Federation', 'CLF', 'Village oversight & analytics'),
  RoleInfo(Role.admin, 'Administrator', 'Admin', 'System, users & schemes'),
];

RoleInfo roleInfoFor(Role r) => roles.firstWhere((e) => e.id == r);

enum Language { en, te, hi }

class AppUser {
  final String name;
  final String mobile;
  final Role role;
  final String shgName;
  final String village;
  const AppUser({
    required this.name,
    required this.mobile,
    required this.role,
    required this.shgName,
    required this.village,
  });

  AppUser copyWith({Role? role, String? name, String? village}) => AppUser(
        name: name ?? this.name,
        mobile: mobile,
        role: role ?? this.role,
        shgName: shgName,
        village: village ?? this.village,
      );
}

const defaultUser = AppUser(
  name: 'Lakshmi Devi',
  mobile: '+91 98765 43210',
  role: Role.member,
  shgName: 'Sri Durga Mahila SHG',
  village: 'Kondapur, Warangal',
);
