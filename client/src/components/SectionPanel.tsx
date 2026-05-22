import type { ReactNode } from 'react';

export function SectionPanel({
  actions,
  children,
  eyebrow,
  title,
}: {
  actions?: ReactNode;
  children: ReactNode;
  eyebrow?: string;
  title: string;
}) {
  return (
    <section className="workflow-panel">
      <div className="workflow-panel__header">
        <div>
          {eyebrow ? <p>{eyebrow}</p> : null}
          <h2>{title}</h2>
        </div>
        {actions ? <div className="workflow-panel__actions">{actions}</div> : null}
      </div>
      {children}
    </section>
  );
}
