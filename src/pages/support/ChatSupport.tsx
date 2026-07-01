import { useState } from 'react'
import { Send, Headset } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Avatar } from '../../components/ui/Avatar'
import { useApp } from '../../context/AppContext'

interface Message {
  id: string
  from: 'agent' | 'user'
  text: string
  time: string
}

const initialMessages: Message[] = [
  { id: 'c1', from: 'agent', text: 'Namaste! I am Saathi Support. How can I help you today?', time: '10:01 AM' },
  { id: 'c2', from: 'user', text: 'I want to know my loan outstanding amount.', time: '10:02 AM' },
  { id: 'c3', from: 'agent', text: 'Sure! Your current outstanding loan balance is ₹22,000, with the next EMI of ₹2,500 due on 10 Jul 2026.', time: '10:02 AM' },
  { id: 'c4', from: 'user', text: 'Thank you! Can I also change my meeting attendance date?', time: '10:03 AM' },
  { id: 'c5', from: 'agent', text: 'Attendance dates are set by your SHG leader. I can help you raise a request — would you like me to do that?', time: '10:03 AM' },
]

export function ChatSupport() {
  const { user } = useApp()
  const [messages, setMessages] = useState<Message[]>(initialMessages)
  const [input, setInput] = useState('')

  function send() {
    const text = input.trim()
    if (!text) return
    const now = new Date()
    const time = now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
    setMessages((m) => [...m, { id: `u-${Date.now()}`, from: 'user', text, time }])
    setInput('')
    setTimeout(() => {
      setMessages((m) => [
        ...m,
        {
          id: `a-${Date.now()}`,
          from: 'agent',
          text: 'Got it! Our support team will look into this and respond shortly.',
          time: now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }),
        },
      ])
    }, 900)
  }

  return (
    <div className="flex h-screen flex-col">
      <PageHeader title="Chat Support" subtitle="Saathi Support Team · Online" />

      <div className="flex-1 overflow-y-auto px-4 py-3 space-y-3">
        {messages.map((m) => (
          <div key={m.id} className={`flex items-end gap-2 ${m.from === 'user' ? 'flex-row-reverse' : ''}`}>
            {m.from === 'agent' ? (
              <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-brand-100 text-brand-600">
                <Headset className="h-3.5 w-3.5" />
              </div>
            ) : (
              <Avatar name={user.name} size="xs" />
            )}
            <div className={`max-w-[75%] rounded-2xl px-3.5 py-2.5 text-sm ${m.from === 'user' ? 'bg-brand-600 text-white rounded-br-sm' : 'bg-white border border-ink-100 text-ink-800 rounded-bl-sm shadow-[var(--shadow-card)]'}`}>
              <p className="leading-relaxed">{m.text}</p>
              <p className={`mt-1 text-[10px] ${m.from === 'user' ? 'text-white/70' : 'text-ink-400'}`}>{m.time}</p>
            </div>
          </div>
        ))}
      </div>

      <form
        className="flex items-center gap-2 border-t border-ink-100 bg-white px-3 py-3 pb-[calc(env(safe-area-inset-bottom)+0.75rem)]"
        onSubmit={(e) => {
          e.preventDefault()
          send()
        }}
      >
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Type your message..."
          className="h-11 flex-1 rounded-xl border border-ink-200 bg-ink-50 px-3.5 text-sm text-ink-900 outline-none placeholder:text-ink-400 focus:border-brand-500 focus:ring-2 focus:ring-brand-100 transition"
        />
        <button
          type="submit"
          className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-600 text-white active:scale-95 transition disabled:opacity-40"
          disabled={!input.trim()}
          aria-label="Send"
        >
          <Send className="h-4.5 w-4.5" />
        </button>
      </form>
    </div>
  )
}
