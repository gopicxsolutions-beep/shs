import { createContext, useContext, useMemo, useState, type ReactNode } from 'react'
import type { AppUser, Language, Role } from '../lib/types'

interface AppContextValue {
  user: AppUser
  setRole: (role: Role) => void
  language: Language
  setLanguage: (lang: Language) => void
  isAuthenticated: boolean
  setAuthenticated: (v: boolean) => void
}

const defaultUser: AppUser = {
  name: 'Lakshmi Devi',
  mobile: '+91 98765 43210',
  role: 'member',
  shgName: 'Sri Durga Mahila SHG',
  avatarColor: 'brand',
  village: 'Kondapur, Warangal',
}

const AppContext = createContext<AppContextValue | null>(null)

export function AppProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AppUser>(defaultUser)
  const [language, setLanguage] = useState<Language>('en')
  const [isAuthenticated, setAuthenticated] = useState(false)

  const value = useMemo<AppContextValue>(
    () => ({
      user,
      setRole: (role) => setUser((u) => ({ ...u, role })),
      language,
      setLanguage,
      isAuthenticated,
      setAuthenticated,
    }),
    [user, language, isAuthenticated],
  )

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>
}

export function useApp() {
  const ctx = useContext(AppContext)
  if (!ctx) throw new Error('useApp must be used within AppProvider')
  return ctx
}
