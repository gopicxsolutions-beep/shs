import type { ReactNode } from 'react'

export function PhoneFrame({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-dvh w-full overscroll-none bg-[radial-gradient(circle_at_20%_0%,#0d6f55_0%,#0a4a3b_38%,#0f1413_100%)] sm:flex sm:items-center sm:justify-center sm:p-6 lg:p-10">
      <div className="mx-auto flex h-dvh w-full max-w-[430px] flex-col overflow-hidden bg-ink-50 sm:h-[880px] sm:max-h-[92vh] sm:rounded-[2.75rem] sm:border-[10px] sm:border-ink-950 sm:shadow-2xl">
        <div className="relative flex h-full w-full flex-1 flex-col overflow-y-auto overscroll-contain no-scrollbar">
          {children}
        </div>
      </div>
    </div>
  )
}
