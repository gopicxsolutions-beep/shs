import { BrowserRouter } from 'react-router-dom'
import { AppProvider } from './context/AppContext'
import { AppRouter } from './routes/AppRouter'

export default function App() {
  return (
    <AppProvider>
      <BrowserRouter>
        <AppRouter />
      </BrowserRouter>
    </AppProvider>
  )
}
