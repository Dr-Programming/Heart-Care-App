import { NavLink } from 'react-router'

const SECTIONS = [
  { to: '/', label: 'Overview' },
  { to: '/api', label: 'API performance' },
  { to: '/database', label: 'Database' },
  { to: '/infrastructure', label: 'Infrastructure' },
  { to: '/network', label: 'Network' },
  { to: '/activity', label: 'Activity' },
  { to: '/demo', label: 'Demonstration' },
] as const

const linkClass = ({ isActive }: { isActive: boolean }) =>
  `block whitespace-nowrap rounded-md px-3 py-2 text-[15px] transition-colors ${
    isActive ? 'bg-raised font-bold text-ink shadow-[inset_3px_0_0_var(--ok)]' : 'text-muted hover:bg-raised/60 hover:text-ink'
  }`

/** Vertical on wide screens, a scrolling strip on narrow ones. */
export function Sidebar() {
  return (
    <nav aria-label="Sections">
      <ul className="flex gap-1 overflow-x-auto pb-1 lg:flex-col lg:overflow-visible lg:pb-0">
        {SECTIONS.map((s) => (
          <li key={s.to}>
            <NavLink to={s.to} end={s.to === '/'} className={linkClass}>
              {s.label}
            </NavLink>
          </li>
        ))}
      </ul>
    </nav>
  )
}
