import { Star } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Avatar } from '../../components/ui/Avatar'
import { EmptyState } from '../../components/ui/EmptyState'
import { reviews } from '../../data/marketplace'

function Stars({ rating }: { rating: number }) {
  return (
    <div className="flex items-center gap-0.5">
      {Array.from({ length: 5 }, (_, i) => (
        <Star
          key={i}
          className={i < rating ? 'h-3.5 w-3.5 fill-gold-500 text-gold-500' : 'h-3.5 w-3.5 text-ink-200'}
        />
      ))}
    </div>
  )
}

export function Reviews() {
  return (
    <div className="pb-6">
      <PageHeader title="Reviews" subtitle={`${reviews.length} customer reviews`} />

      <div className="px-4 mt-2">
        {reviews.length === 0 ? (
          <EmptyState title="No reviews yet" />
        ) : (
          <div className="space-y-3">
            {reviews.map((r) => (
              <Card key={r.id}>
                <div className="flex items-start gap-3">
                  <Avatar name={r.reviewer} size="sm" />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between gap-2">
                      <p className="text-sm font-bold text-ink-900 truncate">{r.reviewer}</p>
                      <Stars rating={r.rating} />
                    </div>
                    <p className="text-xs text-ink-500 mt-0.5">{r.product}</p>
                    <p className="text-sm text-ink-700 mt-2 leading-relaxed">{r.comment}</p>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
