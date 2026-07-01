import { Link } from 'react-router-dom'
import { Star, ShoppingBag, PlusCircle, ClipboardList, MessageSquareText, Package } from 'lucide-react'
import { Card } from '../../components/ui/Card'
import { Badge } from '../../components/ui/Badge'
import { SectionHeader } from '../../components/ui/SectionHeader'
import { IconTile } from '../../components/ui/IconTile'
import { paths } from '../../routes/paths'
import { useData } from '../../context/DataContext'

export function MarketplaceHome() {
  const { products, orders } = useData()
  return (
    <div className="pb-6">
      <div className="bg-gradient-to-br from-brand-700 to-brand-500 px-4 pb-8 pt-[calc(env(safe-area-inset-top)+1.25rem)] text-white">
        <div className="flex items-center gap-3">
          <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-white/15">
            <ShoppingBag className="h-7 w-7" />
          </div>
          <div className="min-w-0 flex-1">
            <h1 className="font-display text-lg font-bold truncate">Marketplace</h1>
            <p className="text-xs text-white/75 mt-0.5">Sell your produce and handicrafts</p>
          </div>
        </div>

        <div className="mt-5 grid grid-cols-2 gap-2 rounded-2xl bg-white/10 p-3 backdrop-blur">
          <div className="text-center">
            <p className="text-sm font-bold">{products.length}</p>
            <p className="text-[10px] text-white/70">Products Listed</p>
          </div>
          <div className="text-center border-l border-white/15">
            <p className="text-sm font-bold">{orders.length}</p>
            <p className="text-[10px] text-white/70">Total Orders</p>
          </div>
        </div>
      </div>

      <div className="px-4 -mt-4 grid grid-cols-3 gap-2">
        <IconTile to={paths.marketplaceAddProduct} icon={<PlusCircle className="h-5.5 w-5.5" />} label="Add Product" tone="brand" />
        <IconTile to={paths.marketplaceOrders} icon={<ClipboardList className="h-5.5 w-5.5" />} label="Orders" tone="gold" />
        <IconTile to={paths.marketplaceReviews} icon={<MessageSquareText className="h-5.5 w-5.5" />} label="Reviews" tone="sky" />
      </div>

      <div className="px-4 mt-6">
        <SectionHeader title="Products" subtitle="From SHG members" icon={<Package className="h-4 w-4 text-ink-400" />} />
        <div className="grid grid-cols-2 gap-3">
          {products.map((p) => (
            <Link key={p.id} to={paths.marketplaceProduct(p.id)}>
              <Card interactive className="!p-3">
                <div className="flex h-24 items-center justify-center rounded-xl bg-brand-50 text-5xl">
                  {p.image}
                </div>
                <p className="text-xs font-bold text-ink-900 mt-2.5 truncate">{p.name}</p>
                <p className="text-[11px] text-ink-500 truncate">{p.seller}</p>
                <div className="flex items-center justify-between mt-2">
                  <p className="text-sm font-bold font-display text-ink-900">
                    ₹{p.price.toLocaleString('en-IN')}
                    <span className="text-[10px] font-normal text-ink-400"> /{p.unit}</span>
                  </p>
                  <Badge tone="gold" dot={false} className="!px-1.5">
                    <Star className="h-2.5 w-2.5 fill-current" /> {p.rating}
                  </Badge>
                </div>
              </Card>
            </Link>
          ))}
        </div>
      </div>
    </div>
  )
}
