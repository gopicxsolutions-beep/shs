import { useState } from 'react'
import { useParams } from 'react-router-dom'
import { Check, Package, User, IndianRupee, Landmark, QrCode } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { Button } from '../../components/ui/Button'
import { EmptyState } from '../../components/ui/EmptyState'
import { cn } from '../../lib/cn'
import { orders, type Order } from '../../data/marketplace'

const steps: { key: Order['status']; label: string }[] = [
  { key: 'new', label: 'New' },
  { key: 'packed', label: 'Packed' },
  { key: 'shipped', label: 'Shipped' },
  { key: 'delivered', label: 'Delivered' },
]

const statusTone: Record<Order['status'], 'brand' | 'warning' | 'info' | 'success'> = {
  new: 'warning',
  packed: 'info',
  shipped: 'brand',
  delivered: 'success',
}

const nextAction: Record<Order['status'], string | null> = {
  new: 'Mark as Packed',
  packed: 'Mark as Shipped',
  shipped: 'Mark as Delivered',
  delivered: null,
}

export function OrderDetail() {
  const { id } = useParams()
  const order = orders.find((o) => o.id === id)
  const [status, setStatus] = useState<Order['status'] | undefined>(order?.status)

  if (!order || !status) {
    return (
      <div>
        <PageHeader title="Order" />
        <div className="px-4 pt-8"><EmptyState title="Order not found" /></div>
      </div>
    )
  }

  const currentIndex = steps.findIndex((s) => s.key === status)
  const action = nextAction[status]

  const handleAdvance = () => {
    const idx = steps.findIndex((s) => s.key === status)
    if (idx < steps.length - 1) setStatus(steps[idx + 1].key)
  }

  return (
    <div className="pb-6">
      <PageHeader title="Order Details" subtitle={order.id.toUpperCase()} />

      <div className="px-4 mt-2">
        <Card>
          <div className="flex items-start justify-between">
            <div className="min-w-0">
              <p className="text-sm font-bold text-ink-900 truncate">{order.product}</p>
              <p className="flex items-center gap-1 text-xs text-ink-500 mt-1">
                <User className="h-3 w-3" /> {order.buyer}
              </p>
            </div>
            <Badge tone={statusTone[status]}>{status}</Badge>
          </div>

          <div className="grid grid-cols-3 gap-2 mt-4 text-center">
            <div>
              <p className="text-sm font-bold font-display text-ink-900">₹{order.amount.toLocaleString('en-IN')}</p>
              <p className="text-[10px] text-ink-500">Amount</p>
            </div>
            <div className="border-x border-ink-100">
              <p className="text-sm font-bold text-ink-900">{order.qty}</p>
              <p className="text-[10px] text-ink-500">Quantity</p>
            </div>
            <div>
              <p className="text-sm font-bold text-ink-900">{order.date}</p>
              <p className="text-[10px] text-ink-500">Order Date</p>
            </div>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-6">
        <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-3">Order Status</p>
        <Card>
          <div className="flex items-start">
            {steps.map((s, i) => (
              <div key={s.key} className="flex flex-1 flex-col items-center relative">
                {i > 0 && (
                  <div
                    className={cn(
                      'absolute top-4 right-1/2 h-0.5 w-full -z-0',
                      i <= currentIndex ? 'bg-brand-600' : 'bg-ink-100',
                    )}
                  />
                )}
                <div
                  className={cn(
                    'relative z-10 flex h-8 w-8 items-center justify-center rounded-full text-xs font-bold',
                    i < currentIndex && 'bg-brand-600 text-white',
                    i === currentIndex && 'bg-brand-600 text-white ring-4 ring-brand-100',
                    i > currentIndex && 'bg-ink-100 text-ink-400',
                  )}
                >
                  {i < currentIndex ? <Check className="h-4 w-4" /> : i + 1}
                </div>
                <span
                  className={cn(
                    'mt-2 text-[11px] font-medium text-center',
                    i <= currentIndex ? 'text-ink-900' : 'text-ink-400',
                  )}
                >
                  {s.label}
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-2">Buyer &amp; Item</p>
        <Card className="!p-0 divide-y divide-ink-100">
          <div className="flex items-center gap-3 px-4 py-3">
            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-brand-50 text-brand-600">
              <Package className="h-4 w-4" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-xs font-semibold text-ink-800 truncate">{order.product}</p>
              <p className="text-[11px] text-ink-400">Qty {order.qty}</p>
            </div>
          </div>
          <div className="flex items-center gap-3 px-4 py-3">
            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-gold-50 text-gold-600">
              <IndianRupee className="h-4 w-4" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-xs font-semibold text-ink-800 truncate">₹{order.amount.toLocaleString('en-IN')}</p>
              <p className="text-[11px] text-ink-400">Total amount</p>
            </div>
          </div>
          <div className="flex items-center gap-3 px-4 py-3">
            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-sky-50 text-sky-600">
              {order.paymentMode === 'UPI' ? <QrCode className="h-4 w-4" /> : <Landmark className="h-4 w-4" />}
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-xs font-semibold text-ink-800 truncate">{order.paymentMode}</p>
              <p className="text-[11px] text-ink-400">Payment method</p>
            </div>
            <Badge tone="success">Paid</Badge>
          </div>
        </Card>
      </div>

      {action && (
        <div className="px-4 mt-6">
          <Button fullWidth size="lg" onClick={handleAdvance}>
            {action}
          </Button>
        </div>
      )}
    </div>
  )
}
