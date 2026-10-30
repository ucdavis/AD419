import type { ReactNode } from 'react';
import type { WorkflowStage } from '../types.ts';

export function StageHeader({
  actions,
  stage,
}: {
  actions?: ReactNode;
  stage: WorkflowStage;
}) {
  return (
    <section className="workflow-stage-header">
      <div>
        <h1>{stage.title}</h1>
      </div>
      <div className="flex flex-wrap gap-2">{actions}</div>
    </section>
  );
}
