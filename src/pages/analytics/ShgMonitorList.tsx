import { PageHeader } from '../../components/layout/PageHeader'
import { shgsForMonitoring } from '../../data/analytics'
import { ShgMonitorListContent } from './ShgMonitorListContent'

export function ShgMonitorList() {
  return (
    <div className="pb-6">
      <PageHeader title="SHGs & Village Organisations" subtitle={`${shgsForMonitoring.length} groups under your cluster`} />
      <ShgMonitorListContent />
    </div>
  )
}
