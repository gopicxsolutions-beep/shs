import { Outlet } from 'react-router-dom'
import { PhoneFrame } from './PhoneFrame'

export function SubPageShell() {
  return (
    <PhoneFrame>
      <div className="flex-1">
        <Outlet />
      </div>
    </PhoneFrame>
  )
}
