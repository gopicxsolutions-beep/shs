export type Role = 'member' | 'leader' | 'crp' | 'clf' | 'admin'

export interface RoleInfo {
  id: Role
  label: string
  shortLabel: string
  description: string
}

export const ROLES: RoleInfo[] = [
  { id: 'member', label: 'SHG Member', shortLabel: 'Member', description: 'Savings, loans, attendance & schemes' },
  { id: 'leader', label: 'SHG Leader / President', shortLabel: 'Leader', description: 'Manage members, meetings & approvals' },
  { id: 'crp', label: 'Community Resource Person', shortLabel: 'CRP', description: 'Monitor SHGs & training' },
  { id: 'clf', label: 'Cluster Level Federation', shortLabel: 'CLF', description: 'Village oversight & analytics' },
  { id: 'admin', label: 'Administrator', shortLabel: 'Admin', description: 'System, users & schemes' },
]

export type Language = 'en' | 'te' | 'hi'

export interface AppUser {
  name: string
  mobile: string
  role: Role
  shgName: string
  avatarColor: string
  village: string
}
