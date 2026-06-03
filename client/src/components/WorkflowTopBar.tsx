import { useUser } from '@/shared/auth/UserContext.tsx';

export function WorkflowTopBar() {
  const user = useUser();
  const initials = user.name
    .split(' ')
    .map((part) => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();

  return (
    <header className="workflow-topbar">
      <div className="workflow-topbar__brand">
        <span className="workflow-topbar__product">DataHelper</span>
        <span className="workflow-topbar__version">2.0</span>
      </div>
      <nav aria-label="Application actions" className="workflow-topbar__actions">
        <div
          aria-label={user.name}
          className="flex h-9 w-9 items-center justify-center rounded-full bg-white text-xs font-bold text-slate-950"
        >
          {initials || 'ST'}
        </div>
      </nav>
    </header>
  );
}
