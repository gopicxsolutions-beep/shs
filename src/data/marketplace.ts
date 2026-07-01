export interface Product {
  id: string
  name: string
  seller: string
  price: number
  unit: string
  category: string
  rating: number
  reviews: number
  image: string
  stock: number
}

export const products: Product[] = [
  { id: 'p1', name: 'Organic Turmeric Powder', seller: 'Anasuya', price: 180, unit: '500g', category: 'Food Processing', rating: 4.8, reviews: 32, image: '🌿', stock: 24 },
  { id: 'p2', name: 'Handwoven Cotton Saree', seller: 'Rajeshwari', price: 1450, unit: '1 pc', category: 'Tailoring', rating: 4.9, reviews: 18, image: '🥻', stock: 6 },
  { id: 'p3', name: 'Bamboo Storage Basket', seller: 'Jyothi', price: 350, unit: '1 pc', category: 'Handicrafts', rating: 4.6, reviews: 21, image: '🧺', stock: 15 },
  { id: 'p4', name: 'Farm Fresh Cow Ghee', seller: 'Lakshmi Devi', price: 620, unit: '500ml', category: 'Dairy', rating: 4.9, reviews: 47, image: '🧈', stock: 10 },
  { id: 'p5', name: 'Country Chicken Eggs', seller: 'Durga Bhavani', price: 8, unit: '1 egg', category: 'Poultry', rating: 4.7, reviews: 29, image: '🥚', stock: 120 },
  { id: 'p6', name: 'Mango Pickle (Homemade)', seller: 'Anasuya', price: 220, unit: '400g jar', category: 'Food Processing', rating: 4.8, reviews: 39, image: '🥭', stock: 18 },
]

export interface Order {
  id: string
  product: string
  buyer: string
  amount: number
  qty: number
  status: 'new' | 'packed' | 'shipped' | 'delivered'
  date: string
  paymentMode: 'UPI' | 'Bank Transfer'
}

export const orders: Order[] = [
  { id: 'o1', product: 'Farm Fresh Cow Ghee', buyer: 'Ravi Kumar, Hanamkonda', amount: 1240, qty: 2, status: 'new', date: '29 Jun 2026', paymentMode: 'UPI' },
  { id: 'o2', product: 'Organic Turmeric Powder', buyer: 'Sunitha Rao', amount: 360, qty: 2, status: 'packed', date: '28 Jun 2026', paymentMode: 'UPI' },
  { id: 'o3', product: 'Bamboo Storage Basket', buyer: 'Priya Sharma', amount: 700, qty: 2, status: 'shipped', date: '25 Jun 2026', paymentMode: 'Bank Transfer' },
  { id: 'o4', product: 'Mango Pickle (Homemade)', buyer: 'Kiran Reddy', amount: 220, qty: 1, status: 'delivered', date: '20 Jun 2026', paymentMode: 'UPI' },
]

export const reviews = [
  { id: 'r1', product: 'Farm Fresh Cow Ghee', reviewer: 'Ravi Kumar', rating: 5, comment: 'Excellent quality, tastes just like homemade ghee!' },
  { id: 'r2', product: 'Handwoven Cotton Saree', reviewer: 'Priya Sharma', rating: 5, comment: 'Beautiful weave and quick delivery.' },
  { id: 'r3', product: 'Organic Turmeric Powder', reviewer: 'Kiran Reddy', rating: 4, comment: 'Good quality, packaging could be better.' },
]
