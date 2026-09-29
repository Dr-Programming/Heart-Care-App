import { Link } from 'react-router'
import type { Activity, Dose, Symptom, Vital } from '../api/types'
import { fmtDateTime, fmtLocalDate, humanizeEnum, VITAL_LABEL, vitalReading } from '../lib/format'
import { DoseBadge, FlagBadge, SeverityBadge } from './Badge'
import type { Column } from './DataTable'
import { KeyValues } from './KeyValues'

const note = (value: string | null) =>
  value ? <span className="block max-w-[32ch] italic">“{value}”</span> : <span className="text-faint">—</span>

function patientColumn<T extends { userId: string; userName: string | null }>(): Column<T> {
  return {
    id: 'patient',
    header: 'Patient',
    cell: ({ row }) => (
      <Link
        to={`/patients/${row.original.userId}`}
        onClick={(e) => e.stopPropagation()}
        className="font-bold underline decoration-line-strong underline-offset-2 hover:decoration-heart"
      >
        {row.original.userName ?? 'Unknown patient'}
      </Link>
    ),
  }
}

export function vitalColumns(withPatient: boolean): Column<Vital>[] {
  return [
    {
      id: 'measuredAt',
      header: 'Measured',
      meta: { sortKey: 'measuredAt', width: '11rem' },
      cell: ({ row }) => <span className="num whitespace-nowrap">{fmtDateTime(row.original.measuredAt)}</span>,
    },
    ...(withPatient ? [patientColumn<Vital>()] : []),
    { id: 'type', header: 'Vital', cell: ({ row }) => VITAL_LABEL[row.original.type] },
    {
      id: 'reading',
      header: 'Reading',
      cell: ({ row }) => {
        const r = vitalReading(row.original.type, row.original.values)
        return (
          <span className="num">
            <span className={`font-bold ${row.original.flagged ? 'text-heart' : ''}`}>{r.main}</span>
            {r.extra && <span className="ml-2 text-muted">{r.extra}</span>}
          </span>
        )
      },
    },
    { id: 'flagged', header: 'Range', cell: ({ row }) => <FlagBadge flagged={row.original.flagged} /> },
    { id: 'note', header: 'Patient note', cell: ({ row }) => note(row.original.note) },
  ]
}

export function symptomColumns(withPatient: boolean): Column<Symptom>[] {
  return [
    {
      id: 'measuredAt',
      header: 'Checked in',
      meta: { sortKey: 'measuredAt', width: '11rem' },
      cell: ({ row }) => <span className="num whitespace-nowrap">{fmtDateTime(row.original.measuredAt)}</span>,
    },
    ...(withPatient ? [patientColumn<Symptom>()] : []),
    { id: 'severity', header: 'Assessment', cell: ({ row }) => <SeverityBadge value={row.original.overallSeverity} /> },
    {
      id: 'data',
      header: 'Reported',
      cell: ({ row }) => {
        // Highlight the symptoms the backend's assessment rated urgent or worse.
        const per = (row.original.assessment?.symptoms ?? {}) as Record<string, string>
        return <KeyValues data={row.original.data} highlight={(k) => per[k] === 'URGENT' || per[k] === 'EMERGENCY'} />
      },
    },
    { id: 'note', header: 'Patient note', cell: ({ row }) => note(row.original.note) },
  ]
}

export function activityColumns(): Column<Activity>[] {
  return [
    {
      id: 'measuredAt',
      header: 'When',
      meta: { sortKey: 'measuredAt', width: '11rem' },
      cell: ({ row }) => <span className="num whitespace-nowrap">{fmtDateTime(row.original.measuredAt)}</span>,
    },
    {
      id: 'type',
      header: 'Activity',
      cell: ({ row }) => {
        const t = row.original.data?.type
        return <span className="font-bold">{typeof t === 'string' ? humanizeEnum(t) : '—'}</span>
      },
    },
    {
      id: 'duration',
      header: 'Minutes',
      meta: { align: 'right' },
      cell: ({ row }) => String(row.original.data?.durationMinutes ?? '—'),
    },
    {
      id: 'details',
      header: 'Details',
      cell: ({ row }) => {
        const { type: _t, durationMinutes: _d, ...rest } = row.original.data ?? {}
        return <KeyValues data={rest} />
      },
    },
    { id: 'note', header: 'Patient note', cell: ({ row }) => note(row.original.note) },
  ]
}

export function doseColumns(): Column<Dose>[] {
  return [
    {
      id: 'scheduledDate',
      header: 'Scheduled',
      meta: { sortKey: 'scheduledDate', width: '11rem' },
      cell: ({ row }) => (
        <span className="num whitespace-nowrap">
          {fmtLocalDate(row.original.scheduledDate)}
          {row.original.scheduledTime && <span className="ml-1.5 text-muted">{row.original.scheduledTime.slice(0, 5)}</span>}
        </span>
      ),
    },
    { id: 'medication', header: 'Medication', cell: ({ row }) => <span className="font-bold">{row.original.medicationName ?? '—'}</span> },
    { id: 'status', header: 'Status', cell: ({ row }) => <DoseBadge value={row.original.status} /> },
    {
      id: 'loggedAt',
      header: 'Logged',
      meta: { sortKey: 'loggedAt' },
      cell: ({ row }) => <span className="num whitespace-nowrap text-muted">{fmtDateTime(row.original.loggedAt)}</span>,
    },
    { id: 'note', header: 'Patient note', cell: ({ row }) => note(row.original.note) },
  ]
}
