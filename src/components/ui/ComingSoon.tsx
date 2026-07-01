import { PageHeader } from '../layout/PageHeader'

export function ComingSoon({ title }: { title: string }) {
  return (
    <div>
      <PageHeader title={title} />
      <div className="flex flex-col items-center justify-center px-6 py-24 text-center">
        <p className="text-sm font-semibold text-ink-500">This screen is under construction</p>
      </div>
    </div>
  )
}
