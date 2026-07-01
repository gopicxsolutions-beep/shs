import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CheckCircle2, UploadCloud, IndianRupee } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input, Textarea } from '../../components/ui/Field'
import { paths } from '../../routes/paths'

const categories = ['Agriculture', 'Dairy', 'Poultry', 'Tailoring', 'Handicrafts', 'Food Processing']

export function AddProduct() {
  const navigate = useNavigate()
  const [name, setName] = useState('')
  const [category, setCategory] = useState(categories[0])
  const [price, setPrice] = useState('100')
  const [unit, setUnit] = useState('1 pc')
  const [stock, setStock] = useState('10')
  const [submitted, setSubmitted] = useState(false)

  if (submitted) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50 text-brand-600">
          <CheckCircle2 className="h-9 w-9" />
        </div>
        <h1 className="mt-5 font-display text-xl font-bold text-ink-900">Product listed!</h1>
        <p className="mt-1.5 text-sm text-ink-500">
          {name || 'Your product'} is now live on the marketplace.
        </p>
        <Button className="mt-8" fullWidth size="lg" onClick={() => navigate(paths.marketplace)}>
          Back to Marketplace
        </Button>
      </div>
    )
  }

  return (
    <div className="pb-6">
      <PageHeader title="Add Product" />
      <form
        className="px-4 mt-2 space-y-4"
        onSubmit={(e) => {
          e.preventDefault()
          setSubmitted(true)
        }}
      >
        <div>
          <label className="mb-1.5 block text-xs font-semibold text-ink-600">Product photo</label>
          <Card className="flex flex-col items-center justify-center gap-2 border-dashed !py-8 text-ink-400">
            <UploadCloud className="h-7 w-7" />
            <span className="text-xs">Tap to upload product photo</span>
          </Card>
        </div>

        <Input
          label="Product name"
          placeholder="e.g. Organic Turmeric Powder"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
        />

        <Card>
          <label className="mb-1.5 block text-xs font-semibold text-ink-600">Category</label>
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            className="h-11 w-full rounded-xl border border-ink-200 bg-white px-3.5 text-sm text-ink-900 outline-none focus:border-brand-500"
          >
            {categories.map((c) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
        </Card>

        <div className="grid grid-cols-2 gap-3">
          <Input
            label="Price"
            type="number"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            icon={<IndianRupee className="h-4 w-4" />}
            required
          />
          <Input
            label="Unit"
            placeholder="e.g. 500g, 1 pc"
            value={unit}
            onChange={(e) => setUnit(e.target.value)}
            required
          />
        </div>

        <Input
          label="Stock quantity"
          type="number"
          value={stock}
          onChange={(e) => setStock(e.target.value)}
          required
        />

        <Textarea label="Description" placeholder="Describe your product" rows={3} />

        <Button type="submit" fullWidth size="lg" className="mt-2">
          List Product
        </Button>
      </form>
    </div>
  )
}
