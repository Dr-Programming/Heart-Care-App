import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router'
import App from './App'
import { AuthProvider } from './auth/AuthContext'
import { ApiError } from './services/client'
import './index.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      // Keep showing the last good numbers while a refresh is in flight or briefly failing.
      placeholderData: (previous: unknown) => previous,
      // Retrying a 4xx never helps; the polling interval already retries everything else.
      retry: (count, error) => count < 1 && !(error instanceof ApiError && error.status >= 400 && error.status < 500),
    },
  },
})

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <AuthProvider>
          <App />
        </AuthProvider>
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>,
)
