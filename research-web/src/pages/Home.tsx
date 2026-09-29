import { Link } from 'react-router'
import type { Dataset } from '../api/types'
import { useAuth } from '../auth/AuthContext'
import { ErrorNote } from '../components/Controls'
import { PageHeader } from '../components/Layout'
import { fmtDate } from '../lib/format'
import { useCatalog } from '../lib/useCatalog'

const DATASETS: Record<Dataset, string> = {
  VITALS: 'Vitals',
  SYMPTOMS: 'Symptom check-ins',
  ACTIVITY: 'Activity',
  MEDICATIONS: 'Medications and doses',
  DEMOGRAPHICS: 'Demographics',
}

function daysLeft(iso: string) {
  return Math.ceil((new Date(iso).getTime() - Date.now()) / 86_400_000)
}

const TOOLS = [
  { to: '/cohorts', title: 'Cohorts', body: 'Define a group of patients once and reuse it in every analysis.' },
  { to: '/explore', title: 'Explore a measure', body: 'Averages, spread and the distribution of any measure, optionally split by group.' },
  { to: '/trends', title: 'Trends', body: 'Weekly or monthly averages and rates, comparing up to three cohorts.' },
  { to: '/outcomes', title: 'Outcomes', body: 'Adherence against blood pressure, correlations between measures, and symptom severity over time.' },
]

export function Home() {
  const { me } = useAuth()
  const { data: c, error } = useCatalog()

  return (
    <>
      <PageHeader title={me ? `Welcome, ${me.fullName}` : 'Your access'}>
        Here’s what your administrator has given you access to. Patients are never identified: no names, phone numbers, exact ages or free-text notes.
      </PageHeader>
      {error && <ErrorNote error={error} />}
      {c && (
        <div className="space-y-8">
          <dl className="grid gap-px overflow-hidden rounded-xl bg-line ring-1 ring-line sm:grid-cols-2 lg:grid-cols-4">
            <div className="bg-surface p-4">
              <dt className="text-[13px] text-muted">What you see</dt>
              <dd className="mt-1 font-bold">{c.accessLevel === 'PSEUDONYMOUS' ? 'Aggregates and pseudonymous records' : 'Aggregates only'}</dd>
            </div>
            <div className="bg-surface p-4">
              <dt className="text-[13px] text-muted">Records covered</dt>
              <dd className="mt-1 font-bold">
                {c.dataFrom || c.dataTo ? `${c.dataFrom ? fmtDate(c.dataFrom) : 'Start'} to ${c.dataTo ? fmtDate(c.dataTo) : 'today'}` : 'All dates'}
              </dd>
            </div>
            <div className="bg-surface p-4">
              <dt className="text-[13px] text-muted">Access ends</dt>
              <dd className="mt-1 font-bold">
                {c.expiresAt ? (
                  <>
                    {fmtDate(c.expiresAt)} <span className="font-normal text-muted">({daysLeft(c.expiresAt)} days left)</span>
                  </>
                ) : (
                  'No end date'
                )}
              </dd>
            </div>
            <div className="bg-surface p-4">
              <dt className="text-[13px] text-muted">Downloads</dt>
              <dd className="mt-1 font-bold">{c.exportAllowed ? 'CSV downloads allowed' : 'Not allowed'}</dd>
            </div>
          </dl>

          <section>
            <h2 className="mb-2 text-[17px] font-bold">Datasets</h2>
            <ul className="flex flex-wrap gap-2">
              {(Object.keys(DATASETS) as Dataset[]).map((d) => {
                const on = c.datasets.includes(d)
                return (
                  <li key={d} className={`rounded-full px-3 py-1 text-[14px] ${on ? 'bg-accent-soft font-bold text-accent' : 'text-faint line-through ring-1 ring-line'}`}>
                    {DATASETS[d]}
                  </li>
                )
              })}
            </ul>
          </section>

          <section>
            <h2 className="mb-3 text-[17px] font-bold">Tools</h2>
            <div className="grid gap-4 sm:grid-cols-2">
              {TOOLS.map((t) => (
                <Link key={t.to} to={t.to} className="rounded-xl bg-surface p-5 ring-1 ring-line hover:ring-accent">
                  <div className="font-bold">{t.title}</div>
                  <p className="mt-1 text-[14px] text-muted">{t.body}</p>
                </Link>
              ))}
            </div>
          </section>

          <section className="max-w-[72ch] text-[14px] text-muted">
            <h2 className="mb-2 text-[17px] font-bold text-ink">How your results are protected</h2>
            <p>
              Any figure describing fewer than <strong className="text-ink">{c.minGroupSize} patients</strong> is hidden, shown as a hatched
              “Hidden” cell. Ages are shown in ten-year bands, dates without times, and
              {c.accessLevel === 'PSEUDONYMOUS' ? ' each patient as a code (like P-7F3AKQ2M) that only you see. ' : ' no individual records are shown. '}
              Your administrator can see every request you make.
            </p>
          </section>
        </div>
      )}
    </>
  )
}
