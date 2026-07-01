import { useState } from 'react'
import { Search } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Input } from '../../components/ui/Field'
import { ListRow } from '../../components/ui/ListRow'
import { Avatar } from '../../components/ui/Avatar'
import { Badge } from '../../components/ui/Badge'
import { Card } from '../../components/ui/Card'
import { members } from '../../data/members'
import { paths } from '../../routes/paths'
import { useNavigate } from 'react-router-dom'

export function MemberDirectory() {
  const [query, setQuery] = useState('')
  const navigate = useNavigate()
  const filtered = members.filter((m) => m.name.toLowerCase().includes(query.toLowerCase()))

  return (
    <div>
      <PageHeader title="Member Directory" subtitle={`${members.length} members`} />
      <div className="px-4 pt-2 pb-1">
        <Input
          placeholder="Search members"
          icon={<Search className="h-4 w-4" />}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>
      <div className="px-4 mt-3">
        <Card className="!p-0 divide-y divide-ink-100">
          {filtered.map((m) => (
            <ListRow
              key={m.id}
              onClick={() => navigate(paths.shgMember(m.id))}
              leading={<Avatar name={m.name} />}
              title={m.name}
              subtitle={`${m.role} · Joined ${m.joiningDate}`}
              trailing={
                <Badge tone={m.status === 'active' ? 'success' : 'neutral'} className="mr-1">
                  {m.status === 'active' ? 'Active' : 'Inactive'}
                </Badge>
              }
              className="px-4"
            />
          ))}
        </Card>
      </div>
    </div>
  )
}
