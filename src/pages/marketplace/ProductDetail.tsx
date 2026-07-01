import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Star, MessageCircle, Package, User, CheckCircle2 } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { Button } from '../../components/ui/Button'
import { EmptyState } from '../../components/ui/EmptyState'
import { paths } from '../../routes/paths'
import { products } from '../../data/marketplace'

export function ProductDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const product = products.find((p) => p.id === id)
  const [ordered, setOrdered] = useState(false)

  if (product && ordered) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50 text-brand-600">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 font-display text-xl font-bold text-ink-900">Order placed!</h1>
        <p className="mt-1.5 text-sm text-ink-500">
          Your order for {product.name} has been sent to {product.seller}. You'll be notified once it's packed.
        </p>
        <Button className="mt-8" fullWidth size="lg" onClick={() => navigate(paths.marketplaceOrders)}>
          View My Orders
        </Button>
      </div>
    )
  }

  if (!product) {
    return (
      <div>
        <PageHeader title="Product" />
        <div className="px-4 pt-8"><EmptyState title="Product not found" /></div>
      </div>
    )
  }

  const stockTone = product.stock === 0 ? 'danger' : product.stock < 10 ? 'warning' : 'success'
  const stockLabel = product.stock === 0 ? 'Out of stock' : `${product.stock} in stock`

  return (
    <div className="pb-24">
      <PageHeader title="Product Details" />

      <div className="px-4 mt-2">
        <Card className="!p-0 overflow-hidden">
          <div className="flex h-48 items-center justify-center bg-brand-50 text-8xl">
            {product.image}
          </div>
          <div className="p-4">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="text-base font-bold text-ink-900 font-display truncate">{product.name}</p>
                <p className="flex items-center gap-1 text-xs text-ink-500 mt-1">
                  <User className="h-3 w-3" /> Sold by <span className="font-semibold text-brand-700">{product.seller}</span>
                </p>
              </div>
              <Badge tone={stockTone}>{stockLabel}</Badge>
            </div>

            <div className="flex items-center justify-between mt-4">
              <p className="text-2xl font-bold font-display text-ink-900">
                ₹{product.price.toLocaleString('en-IN')}
                <span className="text-xs font-normal text-ink-400"> /{product.unit}</span>
              </p>
              <div className="flex items-center gap-1 rounded-full bg-gold-50 px-2.5 py-1">
                <Star className="h-3.5 w-3.5 fill-gold-600 text-gold-600" />
                <span className="text-xs font-bold text-gold-700">{product.rating}</span>
                <span className="text-[11px] text-gold-600">({product.reviews})</span>
              </div>
            </div>
          </div>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-2">Description</p>
        <Card>
          <p className="text-sm text-ink-600 leading-relaxed">
            Freshly made {product.category.toLowerCase()} product by SHG member {product.seller}. Sourced and
            prepared locally with quality ingredients, supporting rural livelihoods through the SHG Saathi
            marketplace.
          </p>
          <div className="flex items-center gap-2 mt-3">
            <Package className="h-4 w-4 text-ink-400" />
            <span className="text-xs text-ink-500">Category: {product.category}</span>
          </div>
        </Card>
      </div>

      <div className="fixed inset-x-0 bottom-0 z-30 border-t border-ink-100 bg-white/95 px-4 py-3 backdrop-blur-md flex gap-3" style={{ paddingBottom: 'calc(env(safe-area-inset-bottom) + 0.75rem)' }}>
        <Button
          variant="outline"
          fullWidth
          size="lg"
          className="flex-1"
          icon={<MessageCircle className="h-4 w-4" />}
          onClick={() => navigate(paths.supportChat)}
        >
          Contact Seller
        </Button>
        <Button fullWidth size="lg" className="flex-1" disabled={product.stock === 0} onClick={() => setOrdered(true)}>
          Buy Now
        </Button>
      </div>
    </div>
  )
}
