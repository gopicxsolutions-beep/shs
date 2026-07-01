import type { ReactNode } from 'react'

export function PhoneFrame({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen w-full bg-[radial-gradient(circle_at_20%_0%,#0d6f55_0%,#0a4a3b_38%,#0f1413_100%)] md:flex md:items-center md:justify-center md:py-10">
      <div className="mx-auto flex w-full max-w-[430px] flex-col bg-ink-50 md:h-[900px] md:max-h-[92vh] md:overflow-hidden md:rounded-[2.75rem] md:border-[10px] md:border-ink-950 md:shadow-2xl">
        <div className="relative flex min-h-screen w-full flex-1 flex-col overflow-y-auto no-scrollbar md:min-h-0">
          {children}
        </div>
      </div>
    </div>
  )
}
