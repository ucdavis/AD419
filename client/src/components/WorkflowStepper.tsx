import type { WorkflowSnapshot, WorkflowStage } from '../types.ts';
import { Link } from '@tanstack/react-router';
import { StatusBadge } from './StatusBadge.tsx';

function stepClasses(stage: WorkflowStage, activeStageId: string) {
  const classes = ['workflow-step'];

  if (stage.id === activeStageId) {
    classes.push('workflow-step--active');
  }

  if (stage.status === 'locked') {
    classes.push('workflow-step--locked');
  }

  return classes.join(' ');
}

export function WorkflowStepper({
  activeStageId,
  snapshot,
}: {
  activeStageId: string;
  snapshot: WorkflowSnapshot;
}) {
  return (
    <ol aria-label="AD419 workflow stages" className="workflow-stepper">
      {snapshot.stages.map((stage) => {
        const content = (
          <>
            <span className="workflow-step__number">{stage.number}</span>
            <span className="workflow-step__text">
              <span className="workflow-step__title">{stage.title}</span>
              <StatusBadge status={stage.status} />
            </span>
          </>
        );

        return (
          <li className={stepClasses(stage, activeStageId)} key={stage.id}>
            {stage.status === 'locked' ? (
              <div aria-disabled="true" className="workflow-step__link">
                {content}
              </div>
            ) : (
              <Link
                className="workflow-step__link"
                params={{ stageId: stage.id }}
                to="/workflow/$stageId"
              >
                {content}
              </Link>
            )}
          </li>
        );
      })}
    </ol>
  );
}
