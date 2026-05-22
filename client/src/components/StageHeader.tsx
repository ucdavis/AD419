import type { WorkflowSnapshot, WorkflowStage } from '../types.ts';
import type { ReactNode } from 'react';

export function StageHeader({
  actions,
  snapshot,
  stage,
}: {
  actions?: ReactNode;
  snapshot: WorkflowSnapshot;
  stage: WorkflowStage;
}) {
  return (
    <section className="workflow-stage-header">
      <div>
        <p className="workflow-kicker">Step {stage.number} of 6</p>
        <h1>{stage.title}</h1>
        <p>{stage.description}</p>
      </div>
      <div className="workflow-stage-header__aside">
        <div>
          <span>Reporting cycle</span>
          <strong>
            {snapshot.cycle.label} - {snapshot.cycle.period}
          </strong>
        </div>
        <div>
          <span>Last activity</span>
          <strong>
            {snapshot.activity.actor} - {snapshot.activity.when}
          </strong>
        </div>
        {actions ? <div className="workflow-action-stack">{actions}</div> : null}
      </div>
    </section>
  );
}
