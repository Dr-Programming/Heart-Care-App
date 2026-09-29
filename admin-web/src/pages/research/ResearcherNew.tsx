import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router'
import { adminApi } from '../../api/admin'
import { ApiError } from '../../api/client'
import type { Grant, IssuedPassword } from '../../api/types'
import { PageHeader } from '../../components/Layout'
import { EMPTY_GRANT, GrantForm } from '../../components/research/GrantForm'
import { PasswordReveal } from '../../components/research/PasswordReveal'

const inputClass =
  'w-full rounded-md bg-surface px-3 py-2 text-ink ring-1 ring-line hover:ring-line-strong focus:ring-2 focus:ring-heart focus:outline-none'

export function ResearcherNew() {
  const navigate = useNavigate()
  const qc = useQueryClient()
  const [username, setUsername] = useState('')
  const [fullName, setFullName] = useState('')
  const [organisation, setOrganisation] = useState('')
  const [grant, setGrant] = useState<Grant>(EMPTY_GRANT)
  const [issued, setIssued] = useState<IssuedPassword | null>(null)

  const create = useMutation({
    mutationFn: () => adminApi.createResearcher({ username: username.trim(), fullName, organisation, grant }),
    onSuccess: (result) => {
      qc.invalidateQueries({ queryKey: ['researchers'] })
      setIssued(result)
    },
  })

  const submit = (e: FormEvent) => {
    e.preventDefault()
    create.mutate()
  }

  return (
    <>
      <Link to="/researchers" className="text-[14px] text-muted underline underline-offset-2 hover:text-ink">
        All researchers
      </Link>
      <div className="mt-2">
        <PageHeader title="Add a researcher">
          The account is created with a one-time password for you to pass on. Their name and username can’t be changed later, by them or by you.
        </PageHeader>
      </div>
      <form onSubmit={submit} className="max-w-3xl space-y-8">
        <fieldset className="grid gap-4 sm:grid-cols-2">
          <legend className="mb-2 font-bold sm:col-span-2">Who they are</legend>
          <label className="block">
            <span className="mb-1 block text-[14px] font-bold">Full name</span>
            <input className={inputClass} required maxLength={255} value={fullName} onChange={(e) => setFullName(e.target.value)} />
          </label>
          <label className="block">
            <span className="mb-1 block text-[14px] font-bold">Organisation</span>
            <input className={inputClass} maxLength={255} value={organisation} onChange={(e) => setOrganisation(e.target.value)} />
          </label>
          <label className="block sm:col-span-2">
            <span className="mb-1 block text-[14px] font-bold">Username</span>
            <input className={`${inputClass} max-w-sm`} required pattern="[a-z0-9][a-z0-9._\-]{2,63}" value={username}
              onChange={(e) => setUsername(e.target.value.toLowerCase())} autoComplete="off" />
            <span className="mt-1 block text-[13px] text-muted">3–64 characters: lowercase letters, digits, dot, dash or underscore.</span>
          </label>
        </fieldset>

        <GrantForm value={grant} onChange={setGrant} />

        {create.error && (
          <p role="alert" className="rounded-md bg-heart-soft px-3 py-2 text-heart">
            {create.error instanceof ApiError ? create.error.message : 'Couldn’t create the researcher.'}
          </p>
        )}
        <div className="flex gap-3">
          <button type="submit" disabled={create.isPending || grant.datasets.length === 0}
            className="rounded-md bg-heart px-4 py-2 font-bold text-white hover:brightness-110 disabled:opacity-50">
            {create.isPending ? 'Creating…' : 'Create researcher'}
          </button>
          <Link to="/researchers" className="rounded-md px-4 py-2 ring-1 ring-line hover:ring-line-strong">Cancel</Link>
        </div>
      </form>
      {issued && (
        <PasswordReveal
          title="Researcher created"
          username={issued.researcher.username}
          password={issued.password}
          onClose={() => navigate(`/researchers/${issued.researcher.id}`, { replace: true })}
        />
      )}
    </>
  )
}
