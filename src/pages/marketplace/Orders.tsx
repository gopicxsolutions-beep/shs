import { useState } from 'react'
import { Link } from 'react-router-dom'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { SegmentedTabs } from '../../components/ui/SegmentedTabs'
import { EmptyState } from '../../components/ui/EmptyState'
import { paths } from '../../routes/paths'
import type { Order } from '../../data/marketplace'
import { useData } from '../../context/DataContext'

const statusTone: Record<Order['status'], 'brand' | 'warning' | 'info' | 'success'> = {
  new: 'warning',
  packed: 'info',
  shipped: 'brand',
  delivered: 'success',
}

const filters = [
  { value: 'all', label: 'All' },
  { value: 'new', label: 'New' },
  { value: 'packed', label: 'Packed' },
  { value: 'shipped', label: 'Shipped' },
  { value: 'delivered', label: 'Delivered' },
]

export function Orders() {
  const { orders } = useData()
  const [status, setStatus] = useState('all')
  const filtered = status === 'all' ? orders : orders.filter((o) => o.status === status)

  return (
    <div className="pb-6">
      <PageHeader title="Orders" subtitle={`${orders.length} total orders`} />

      <div className="px-4 mt-2">
        <SegmentedTabs options={filters} value={status} onChange={setStatus} />
      </div>

      <div className="px-4 mt-5">
        {filtered.length === 0 ? (
          <EmptyState title="No orders in this status" />
        ) : (
          <div className="space-y-3">
            {filtered.map((o) => (
              <Link key={o.id} to={paths.marketplaceOrderDetail(o.id)}>
                <Card interactive>
                  <div className="flex items-start justify-between">
                    <div className="min-w-0">
                      <p className="text-sm font-bold text-ink-900 truncate">{o.product}</p>
                      <p className="text-xs text-ink-500 mt-0.5 truncate">{o.buyer}</p>
                    </div>
                    <Badge tone={statusTone[o.status]}>{o.status}</Badge>
                  </div>
                  <div className="flex items-end justify-between mt-3">
                    <p className="text-base font-bold font-display text-ink-900">₹{o.amount.toLocaleString('en-IN')}</p>
                    <p className="text-xs text-ink-500">Qty {o.qty} · {o.date}</p>
                  </div>
                  <p className="text-[11px] text-ink-400 mt-1">Paid via {o.paymentMode}</p>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
