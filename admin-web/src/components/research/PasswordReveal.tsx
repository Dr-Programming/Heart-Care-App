import { useEffect, useRef, useState } from 'react'

/**
 * Shows an admin-issued password exactly once. The server never returns it again, so the dialog
 * makes that consequence explicit and offers copy before it can be dismissed.
 */
export function PasswordReveal({
  username,
  password,
  onClose,
  title,
}: {
  username: string
  password: string
  onClose: () => void
  title: string
}) {
  const [copied, setCopied] = useState(false)
  const ref = useRef<HTMLDialogElement>(null)

  useEffect(() => {
    ref.current?.showModal()
  }, [])

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(password)
      setCopied(true)
    } catch {
      setCopied(false)
    }
  }

  return (
    <dialog
      ref={ref}
      onCancel={(e) => e.preventDefault()}
      className="m-auto w-[min(32rem,calc(100vw-2rem))] rounded-xl bg-surface p-6 text-ink ring-1 ring-line-strong backdrop:bg-black/40"
    >
      <h2 className="text-[20px] font-bold">{title}</h2>
      <p className="mt-2 text-muted">
        Give these sign-in details to the researcher over a secure channel. They must replace the password the first time they sign in,
        and after that only you can reset it.
      </p>
      <dl className="mt-5 space-y-3">
        <div>
          <dt className="text-[13px] text-muted">Username</dt>
          <dd className="num font-bold">{username}</dd>
        </div>
        <div>
          <dt className="text-[13px] text-muted">Temporary password</dt>
          <dd className="mt-1 flex items-center gap-2">
            <code className="num rounded-md bg-paper px-3 py-2 text-[18px] font-bold tracking-wide ring-1 ring-line">{password}</code>
            <button type="button" onClick={copy} className="rounded-md px-3 py-2 font-bold ring-1 ring-line hover:ring-line-strong">
              {copied ? 'Copied' : 'Copy'}
            </button>
          </dd>
        </div>
      </dl>
      <p className="mt-5 rounded-md bg-amber-soft px-3 py-2 text-[14px] text-amber">
        This password won’t be shown again. If it’s lost, reset it to issue a new one.
      </p>
      <div className="mt-5 flex justify-end">
        <button type="button" onClick={onClose} className="rounded-md bg-heart px-4 py-2 font-bold text-white hover:brightness-110">
          I’ve saved it
        </button>
      </div>
    </dialog>
  )
}
