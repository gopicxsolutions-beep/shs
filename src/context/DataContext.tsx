import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { savingsEntries as initialSavings, type SavingsEntry } from '../data/savings'
import { loans as initialLoans, type Loan } from '../data/loans'
import { meetings as initialMeetings, type Meeting } from '../data/meetings'
import { products as initialProducts, orders as initialOrders, type Product, type Order } from '../data/marketplace'
import { schemes as initialSchemes, type Scheme } from '../data/schemes'
import { activities as initialActivities, type Activity } from '../data/livelihood'
import { members } from '../data/members'

function genId(prefix: string) {
  return `${prefix}-${Date.now().toString(36)}${Math.random().toString(36).slice(2, 5)}`
}

function useStoredState<T>(key: string, initial: T) {
  const [state, setState] = useState<T>(() => {
    try {
      const raw = localStorage.getItem(key)
      return raw ? (JSON.parse(raw) as T) : initial
    } catch {
      return initial
    }
  })
  useEffect(() => {
    try {
      localStorage.setItem(key, JSON.stringify(state))
    } catch {
      // ignore quota/serialization errors — in-memory state still works
    }
  }, [key, state])
  return [state, setState] as const
}

interface DataContextValue {
  savingsEntries: SavingsEntry[]
  addSavingsEntry: (entry: Omit<SavingsEntry, 'id' | 'status'>) => void

  loans: Loan[]
  addLoanRequest: (loan: Omit<Loan, 'id' | 'status' | 'outstanding' | 'emi' | 'disbursedOn'>) => void
  decideLoan: (id: string, decision: 'approved' | 'rejected') => void
  payLoanEmi: (id: string) => void

  meetings: Meeting[]
  addMeeting: (meeting: Omit<Meeting, 'id' | 'status' | 'attendance' | 'total'>) => void
  markAttendance: (meetingId: string, presentCount: number) => void

  products: Product[]
  addProduct: (product: Omit<Product, 'id'>) => void

  orders: Order[]
  addOrder: (order: Omit<Order, 'id' | 'status' | 'date'>) => void
  advanceOrder: (id: string) => void

  schemes: Scheme[]
  applyScheme: (id: string) => void

  activities: Activity[]
  addActivity: (activity: Omit<Activity, 'id'>) => void

  resetDemoData: () => void
}

const DataContext = createContext<DataContextValue | null>(null)

const orderSteps: Order['status'][] = ['new', 'packed', 'shipped', 'delivered']

export function DataProvider({ children }: { children: ReactNode }) {
  const [savingsEntries, setSavingsEntries] = useStoredState('shg-savings', initialSavings)
  const [loans, setLoans] = useStoredState('shg-loans', initialLoans)
  const [meetings, setMeetings] = useStoredState('shg-meetings', initialMeetings)
  const [products, setProducts] = useStoredState('shg-products', initialProducts)
  const [orders, setOrders] = useStoredState('shg-orders', initialOrders)
  const [schemes, setSchemes] = useStoredState('shg-schemes', initialSchemes)
  const [activities, setActivities] = useStoredState('shg-activities', initialActivities)

  const value: DataContextValue = {
    savingsEntries,
    addSavingsEntry: (entry) => {
      setSavingsEntries((prev) => [{ ...entry, id: genId('s'), status: 'pending' }, ...prev])
    },

    loans,
    addLoanRequest: (loan) => {
      setLoans((prev) => [
        { ...loan, id: genId('l'), status: 'pending', outstanding: loan.amount, emi: 0, disbursedOn: '' },
        ...prev,
      ])
    },
    decideLoan: (id, decision) => {
      setLoans((prev) =>
        prev.map((l) => {
          if (l.id !== id) return l
          if (decision === 'rejected') return { ...l, status: 'rejected' }
          const emi = Math.round(l.amount / l.tenureMonths)
          return { ...l, status: 'active', emi, disbursedOn: 'Just now', nextDueDate: 'Next month', outstanding: l.amount }
        }),
      )
    },
    payLoanEmi: (id) => {
      setLoans((prev) =>
        prev.map((l) => {
          if (l.id !== id) return l
          const outstanding = Math.max(0, l.outstanding - l.emi)
          return { ...l, outstanding, status: outstanding === 0 ? 'closed' : l.status }
        }),
      )
    },

    meetings,
    addMeeting: (meeting) => {
      setMeetings((prev) => [{ ...meeting, id: genId('mt'), status: 'upcoming', attendance: 0, total: members.length }, ...prev])
    },
    markAttendance: (meetingId, presentCount) => {
      setMeetings((prev) =>
        prev.map((m) => (m.id === meetingId ? { ...m, attendance: presentCount, status: 'completed' } : m)),
      )
    },

    products,
    addProduct: (product) => {
      setProducts((prev) => [{ ...product, id: genId('p') }, ...prev])
    },

    orders,
    addOrder: (order) => {
      setOrders((prev) => [{ ...order, id: genId('o'), status: 'new', date: 'Just now' }, ...prev])
    },
    advanceOrder: (id) => {
      setOrders((prev) =>
        prev.map((o) => {
          if (o.id !== id) return o
          const idx = orderSteps.indexOf(o.status)
          return idx < orderSteps.length - 1 ? { ...o, status: orderSteps[idx + 1] } : o
        }),
      )
    },

    schemes,
    applyScheme: (id) => {
      setSchemes((prev) => prev.map((s) => (s.id === id ? { ...s, status: 'applied' } : s)))
    },

    activities,
    addActivity: (activity) => {
      setActivities((prev) => [{ ...activity, id: genId('a') }, ...prev])
    },

    resetDemoData: () => {
      setSavingsEntries(initialSavings)
      setLoans(initialLoans)
      setMeetings(initialMeetings)
      setProducts(initialProducts)
      setOrders(initialOrders)
      setSchemes(initialSchemes)
      setActivities(initialActivities)
    },
  }

  return <DataContext.Provider value={value}>{children}</DataContext.Provider>
}

export function useData() {
  const ctx = useContext(DataContext)
  if (!ctx) throw new Error('useData must be used within DataProvider')
  return ctx
}
