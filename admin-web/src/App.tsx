import { lazy, Suspense } from 'react'
import { Link, Route, Routes } from 'react-router'
import { RequireAuth } from './auth/AuthContext'
import { Layout, PageHeader } from './components/Layout'
import { Login } from './pages/Login'
import { PatientDetail } from './pages/PatientDetail'
import { Patients } from './pages/Patients'
import { FlaggedVitals, UrgentSymptoms } from './pages/Triage'

// The overview carries the charting library; loading it on demand halves the initial bundle.
const Overview = lazy(() => import('./pages/Overview').then((m) => ({ default: m.Overview })))

function NotFound() {
  return (
    <>
      <PageHeader title="Page not found">That address doesn’t match any page in the admin panel.</PageHeader>
      <Link to="/" className="font-bold underline underline-offset-2">
        Go to the overview
      </Link>
    </>
  )
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        element={
          <RequireAuth>
            <Layout />
          </RequireAuth>
        }
      >
        <Route
          index
          element={
            <Suspense fallback={<div className="ecg-paper h-72 animate-pulse rounded-xl ring-1 ring-line" />}>
              <Overview />
            </Suspense>
          }
        />
        <Route path="patients" element={<Patients />} />
        <Route path="patients/:id" element={<PatientDetail />} />
        <Route path="flagged-vitals" element={<FlaggedVitals />} />
        <Route path="urgent-symptoms" element={<UrgentSymptoms />} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  )
}
