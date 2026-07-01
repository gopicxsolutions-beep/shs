import { Phone } from 'lucide-react'
import { MessageCircle, Mic, HelpCircle, Ticket } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { IconTile } from '../../components/ui/IconTile'
import { paths } from '../../routes/paths'

export function SupportHome() {
  return (
    <div className="pb-6">
      <PageHeader title="Help & Support" subtitle="We're here to help you" />

      <div className="px-4 mt-2 grid grid-cols-4 gap-2">
        <IconTile to={paths.supportChat} icon={<MessageCircle className="h-5.5 w-5.5" />} label="Chat Support" tone="brand" />
        <IconTile to={paths.supportVoice} icon={<Mic className="h-5.5 w-5.5" />} label="Voice Assistant" tone="violet" />
        <IconTile to={paths.supportFaq} icon={<HelpCircle className="h-5.5 w-5.5" />} label="FAQs" tone="gold" />
        <IconTile to={paths.supportTicket} icon={<Ticket className="h-5.5 w-5.5" />} label="Raise Ticket" tone="sky" />
      </div>

      <div className="px-4 mt-6">
        <Card className="flex items-center gap-3 bg-gradient-to-r from-brand-700 to-brand-600 text-white">
          <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-white/15">
            <Phone className="h-5.5 w-5.5" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-bold">Call Helpline</p>
            <p className="text-xs text-white/75">1800-123-4567 · Toll free · 8 AM – 8 PM</p>
          </div>
          <Button
            size="sm"
            variant="gold"
            onClick={() => {
              window.location.href = 'tel:18001234567'
            }}
          >
            Call
          </Button>
        </Card>
      </div>

      <div className="px-4 mt-5">
        <Card>
          <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-2">Need more help?</p>
          <p className="text-xs text-ink-500 leading-relaxed">
            Our support team is available in Telugu, Hindi and English. Reach out via chat, voice assistant or
            raise a support ticket and our team will get back within 24 hours.
          </p>
        </Card>
      </div>
    </div>
  )
}
