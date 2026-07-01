import { BrowserRouter } from 'react-router-dom'
import { AppProvider } from './context/AppContext'
import { DataProvider } from './context/DataContext'
import { AppRouter } from './routes/AppRouter'

export default function App() {
  return (
    <AppProvider>
      <DataProvider>
        <BrowserRouter>
          <AppRouter />
        </BrowserRouter>
      </DataProvider>
    </AppProvider>
  )
}
