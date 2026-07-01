import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { UserCircle2, Search } from 'lucide-react'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Field'
import { Card } from '../../components/ui/Card'
import { paths } from '../../routes/paths'
import { shgInfo } from '../../data/shg'

export function ProfileSetup() {
  const navigate = useNavigate()
  const [name, setName] = useState('')
  const [selectedShg, setSelectedShg] = useState(false)

  return (
    <div className="min-h-screen bg-ink-50 px-6 pb-8 pt-16">
      <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-3xl bg-brand-600 shadow-lg shadow-brand-600/30">
        <UserCircle2 className="h-8 w-8 text-white" />
      </div>
      <h1 className="mt-6 text-center font-display text-2xl font-bold text-ink-900">Create your profile</h1>
      <p className="mt-1.5 text-center text-sm text-ink-500">Tell us a bit about yourself to get started</p>

      <form
        className="mt-8 space-y-4"
        onSubmit={(e) => {
          e.preventDefault()
          navigate(paths.roleSelect)
        }}
      >
        <Input label="Full name" placeholder="e.g. Lakshmi Devi" value={name} onChange={(e) => setName(e.target.value)} required />
        <div className="grid grid-cols-2 gap-3">
          <Input label="Village" placeholder="Kondapur" defaultValue="Kondapur" required />
          <Input label="Mandal" placeholder="Hanamkonda" defaultValue="Hanamkonda" required />
        </div>
        <Input label="District" placeholder="Warangal" defaultValue="Warangal" required />

        <div>
          <span className="mb-1.5 block text-xs font-semibold text-ink-600">Your SHG</span>
          <Card
            interactive
            onClick={() => setSelectedShg(true)}
            className={selectedShg ? 'border-brand-500 ring-2 ring-brand-100' : ''}
          >
            {selectedShg ? (
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-bold text-ink-900">{shgInfo.name}</p>
                  <p className="text-xs text-ink-500 mt-0.5">{shgInfo.village}, {shgInfo.district}</p>
                </div>
                <span className="text-xs font-semibold text-brand-600">Selected</span>
              </div>
            ) : (
              <div className="flex items-center gap-2 text-ink-500">
                <Search className="h-4 w-4" />
                <span className="text-sm">Search &amp; select your SHG</span>
              </div>
            )}
          </Card>
        </div>

        <Button type="submit" fullWidth size="lg" className="mt-2" disabled={!name || !selectedShg}>
          Continue
        </Button>
      </form>
    </div>
  )
}
