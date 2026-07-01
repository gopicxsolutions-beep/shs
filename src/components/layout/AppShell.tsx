import { Outlet } from 'react-router-dom'
import { BottomNav } from './BottomNav'
import { PhoneFrame } from './PhoneFrame'

export function AppShell() {
  return (
    <PhoneFrame>
      <div className="flex-1 pb-2">
        <Outlet />
      </div>
      <BottomNav />
    </PhoneFrame>
  )
}
