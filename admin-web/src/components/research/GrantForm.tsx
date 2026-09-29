import type { AccessLevel, Dataset, Grant } from '../../api/types'

export const DATASET_LABEL: Record<Dataset, { label: string; hint: string }> = {
  VITALS: { label: 'Vitals', hint: 'Blood pressure, glucose, heart rate, weight, cholesterol' },
  SYMPTOMS: { label: 'Symptom check-ins', hint: 'Reported symptoms and the app’s severity assessment' },
  ACTIVITY: { label: 'Activity', hint: 'Activity type, minutes, steps, distance' },
  MEDICATIONS: { label: 'Medications and doses', hint: 'Medication names, doses, taken/missed history' },
  DEMOGRAPHICS: { label: 'Demographics', hint: 'Age band, CHD stage, other conditions, language' },
}

export const LEVEL_LABEL: Record<AccessLevel, { label: string; hint: string }> = {
  AGGREGATE: {
    label: 'Aggregates only',
    hint: 'Counts, averages, distributions and trends. Groups smaller than the minimum size are hidden.',
  },
  PSEUDONYMOUS: {
    label: 'Pseudonymous records',
    hint: 'Aggregates plus row-level records under a random code per patient (e.g. P-7F3AKQ2M). Never names, phones or notes.',
  },
}

export const EMPTY_GRANT: Grant = {
  accessLevel: 'AGGREGATE',
  datasets: ['VITALS'],
  exportAllowed: false,
  dataFrom: null,
  dataTo: null,
  expiresAt: null,
}

const inputClass =
  'rounded-md bg-surface px-2.5 py-1.5 text-[14px] text-ink ring-1 ring-line hover:ring-line-strong focus:ring-heart focus:outline-none'

/** Expiry is chosen as a day; access ends at the end of that day (UTC). */
const expiryDay = (iso: string | null) => (iso ? iso.slice(0, 10) : '')
const expiryIso = (day: string) => (day ? `${day}T23:59:59Z` : null)

export function GrantForm({ value, onChange, disabled }: { value: Grant; onChange: (g: Grant) => void; disabled?: boolean }) {
  const set = (patch: Partial<Grant>) => onChange({ ...value, ...patch })
  const toggle = (d: Dataset) =>
    set({ datasets: value.datasets.includes(d) ? value.datasets.filter((x) => x !== d) : [...value.datasets, d] })

  return (
    <fieldset disabled={disabled} className="space-y-6 disabled:opacity-70">
      <fieldset>
        <legend className="mb-2 font-bold">What they can see</legend>
        <div className="grid gap-2 sm:grid-cols-2">
          {(Object.keys(LEVEL_LABEL) as AccessLevel[]).map((level) => (
            <label
              key={level}
              className={`flex cursor-pointer gap-3 rounded-lg p-3 ring-1 ${
                value.accessLevel === level ? 'bg-surface ring-2 ring-heart' : 'ring-line hover:ring-line-strong'
              }`}
            >
              <input
                type="radio"
                name="accessLevel"
                className="mt-1 accent-[var(--heart)]"
                checked={value.accessLevel === level}
                onChange={() => set({ accessLevel: level })}
              />
              <span>
                <span className="block font-bold">{LEVEL_LABEL[level].label}</span>
                <span className="block text-[13px] text-muted">{LEVEL_LABEL[level].hint}</span>
              </span>
            </label>
          ))}
        </div>
      </fieldset>

      <fieldset>
        <legend className="mb-2 font-bold">Datasets</legend>
        <div className="grid gap-2 sm:grid-cols-2">
          {(Object.keys(DATASET_LABEL) as Dataset[]).map((d) => (
            <label key={d} className="flex cursor-pointer gap-3 rounded-lg p-3 ring-1 ring-line hover:ring-line-strong">
              <input
                type="checkbox"
                className="mt-1 accent-[var(--heart)]"
                checked={value.datasets.includes(d)}
                onChange={() => toggle(d)}
              />
              <span>
                <span className="block font-bold">{DATASET_LABEL[d].label}</span>
                <span className="block text-[13px] text-muted">{DATASET_LABEL[d].hint}</span>
              </span>
            </label>
          ))}
        </div>
        {value.datasets.length === 0 && <p className="mt-2 text-[14px] text-heart">Choose at least one dataset.</p>}
      </fieldset>

      <fieldset className="grid gap-4 sm:grid-cols-3">
        <legend className="mb-2 font-bold sm:col-span-3">Limits</legend>
        <label className="flex flex-col gap-1 text-[13px] text-muted">
          Data from
          <input type="date" className={inputClass} value={value.dataFrom ?? ''} max={value.dataTo ?? undefined}
            onChange={(e) => set({ dataFrom: e.target.value || null })} />
        </label>
        <label className="flex flex-col gap-1 text-[13px] text-muted">
          Data to
          <input type="date" className={inputClass} value={value.dataTo ?? ''} min={value.dataFrom ?? undefined}
            onChange={(e) => set({ dataTo: e.target.value || null })} />
        </label>
        <label className="flex flex-col gap-1 text-[13px] text-muted">
          Access ends after
          <input type="date" className={inputClass} value={expiryDay(value.expiresAt)}
            onChange={(e) => set({ expiresAt: expiryIso(e.target.value) })} />
        </label>
        <p className="text-[13px] text-muted sm:col-span-3">
          Leave a date empty for no limit. The data window limits which records are included; access ends automatically at the end of the chosen day (UTC).
        </p>
      </fieldset>

      <label className="flex cursor-pointer gap-3">
        <input type="checkbox" className="mt-1 accent-[var(--heart)]" checked={value.exportAllowed}
          onChange={(e) => set({ exportAllowed: e.target.checked })} />
        <span>
          <span className="block font-bold">Allow CSV downloads</span>
          <span className="block text-[13px] text-muted">
            Lets the researcher download their results{value.accessLevel === 'PSEUDONYMOUS' ? ' and pseudonymous records' : ''}. Every download is logged.
          </span>
        </span>
      </label>
    </fieldset>
  )
}
