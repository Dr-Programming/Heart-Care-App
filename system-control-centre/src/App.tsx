import { lazy, Suspense, type ReactNode } from 'react'
import { Link, Route, Routes } from 'react-router'
import { RequireAuth } from './auth/AuthContext'
import { PageTitle } from './components/Panel'
import { QueryState } from './components/SourceUnavailable'
import { ConsoleLayout } from './layouts/ConsoleLayout'
import { Login } from './pages/Login'

// Pages load on demand so the sign-in screen does not wait for the charting library.
const Overview = lazy(() => import('./pages/Overview').then((m) => ({ default: m.Overview })))
const ApiPerformance = lazy(() => import('./pages/ApiPerformance').then((m) => ({ default: m.ApiPerformance })))
const Database = lazy(() => import('./pages/Database').then((m) => ({ default: m.Database })))
const Infrastructure = lazy(() => import('./pages/Infrastructure').then((m) => ({ default: m.Infrastructure })))
const Network = lazy(() => import('./pages/Network').then((m) => ({ default: m.Network })))
const Activity = lazy(() => import('./pages/Activity').then((m) => ({ default: m.Activity })))
const Demo = lazy(() => import('./pages/Demo').then((m) => ({ default: m.Demo })))

const page = (node: ReactNode) => <Suspense fallback={<QueryState isLoading error={null} />}>{node}</Suspense>

function NotFound() {
  return (
    <>
      <PageTitle title="Page not found">That address doesn’t match any section of the console.</PageTitle>
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
            <ConsoleLayout />
          </RequireAuth>
        }
      >
        <Route index element={page(<Overview />)} />
        <Route path="api" element={page(<ApiPerformance />)} />
        <Route path="database" element={page(<Database />)} />
        <Route path="infrastructure" element={page(<Infrastructure />)} />
        <Route path="network" element={page(<Network />)} />
        <Route path="activity" element={page(<Activity />)} />
        <Route path="demo" element={page(<Demo />)} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  )
}
