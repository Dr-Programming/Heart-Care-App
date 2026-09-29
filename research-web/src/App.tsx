import { lazy, Suspense, type ReactNode } from 'react'
import { Link, Route, Routes } from 'react-router'
import { RequireAuth } from './auth/AuthContext'
import { Layout, PageHeader } from './components/Layout'
import { Account } from './pages/Account'
import { ChangePassword } from './pages/ChangePassword'
import { Cohorts } from './pages/Cohorts'
import { Explore } from './pages/Explore'
import { Home } from './pages/Home'
import { Login } from './pages/Login'
import { Records } from './pages/Records'

// Charting pages carry Recharts; load them on demand.
const Trends = lazy(() => import('./pages/Trends').then((m) => ({ default: m.Trends })))
const Outcomes = lazy(() => import('./pages/Outcomes').then((m) => ({ default: m.Outcomes })))

const loading = <div className="graph-paper h-72 animate-pulse rounded-xl ring-1 ring-line" />
const lazyPage = (node: ReactNode) => <Suspense fallback={loading}>{node}</Suspense>

function NotFound() {
  return (
    <>
      <PageHeader title="Page not found">That address doesn’t match any page here.</PageHeader>
      <Link to="/" className="font-bold underline underline-offset-2">Go to your access summary</Link>
    </>
  )
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/change-password" element={<RequireAuth><ChangePassword /></RequireAuth>} />
      <Route element={<RequireAuth><Layout /></RequireAuth>}>
        <Route index element={<Home />} />
        <Route path="cohorts" element={<Cohorts />} />
        <Route path="explore" element={<Explore />} />
        <Route path="trends" element={lazyPage(<Trends />)} />
        <Route path="outcomes" element={lazyPage(<Outcomes />)} />
        <Route path="records" element={<Records />} />
        <Route path="account" element={<Account />} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  )
}
