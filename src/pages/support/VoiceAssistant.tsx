import { useState } from 'react'
import { Mic } from 'lucide-react'
import { PageHeader } from '../../components/layout/PageHeader'
import { SegmentedTabs } from '../../components/ui/SegmentedTabs'
import { Card } from '../../components/ui/Card'

const languageOptions = [
  { value: 'en', label: 'English' },
  { value: 'te', label: 'తెలుగు' },
  { value: 'hi', label: 'हिंदी' },
]

const commandsByLang: Record<string, string[]> = {
  en: ['Show my loan details', 'How much did I save this month?', 'When is the next meeting?'],
  te: ['నా రుణ వివరాలు చూపించు', 'ఈ నెల పొదుపు ఎంత?', 'తదుపరి సమావేశం ఎప్పుడు?'],
  hi: ['मेरे लोन का विवरण दिखाएं', 'इस महीने कितनी बचत हुई?', 'अगली बैठक कब है?'],
}

export function VoiceAssistant() {
  const [lang, setLang] = useState('te')
  const [listening, setListening] = useState(false)
  const [transcript, setTranscript] = useState('')

  return (
    <div className="pb-6">
      <PageHeader title="Voice Assistant" subtitle="Ask Saathi anything, in your language" />

      <div className="px-4 mt-2">
        <SegmentedTabs options={languageOptions} value={lang} onChange={setLang} />
      </div>

      <div className="px-6 mt-8 flex flex-col items-center text-center">
        <button
          onClick={() => setListening((v) => !v)}
          className={`relative flex h-32 w-32 items-center justify-center rounded-full transition ${
            listening ? 'bg-violet-600 text-white shadow-[0_10px_28px_-6px_rgba(124,58,237,0.55)]' : 'bg-violet-50 text-violet-600'
          }`}
        >
          {listening && (
            <>
              <span className="absolute inset-0 rounded-full bg-violet-400/40 animate-ping" />
              <span className="absolute -inset-3 rounded-full border-2 border-violet-300/60 animate-pulse" />
            </>
          )}
          <Mic className="relative h-12 w-12" />
        </button>
        <p className="mt-6 text-sm font-semibold text-ink-800">
          {listening ? 'Listening...' : 'Tap the mic to speak'}
        </p>
        <p className="mt-1 text-xs text-ink-500 max-w-[240px]">
          Try asking about your savings, loans, meetings or government schemes.
        </p>
      </div>

      <div className="px-4 mt-6">
        <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-2">Try saying</p>
        <div className="flex flex-wrap gap-2">
          {commandsByLang[lang].map((cmd) => (
            <button
              key={cmd}
              onClick={() => {
                setTranscript(cmd)
                setListening(true)
                setTimeout(() => setListening(false), 1200)
              }}
              className="rounded-full border border-violet-200 bg-violet-50 px-3.5 py-2 text-xs font-medium text-violet-700 active:scale-95 transition"
            >
              {cmd}
            </button>
          ))}
        </div>
      </div>

      <div className="px-4 mt-5">
        <Card className={transcript ? 'border-violet-200' : ''}>
          <p className="text-xs font-bold uppercase tracking-wide text-ink-400 mb-2">Transcript</p>
          <p className="text-sm text-ink-800 min-h-10">
            {transcript || 'Your spoken command will appear here...'}
          </p>
        </Card>
      </div>
    </div>
  )
}
