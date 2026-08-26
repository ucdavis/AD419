import type { WorkflowSnapshot, WorkflowStage } from '../types.ts';
import { Link } from '@tanstack/react-router';

const LOCKED_STAGE_HINT = 'Locked until all previous steps are complete.';

function stepClasses(stage: WorkflowStage, activeStageId: string) {
  const classes = ['workflow-step'];

  if (stage.id === activeStageId) {
    classes.push('workflow-step--active');
  }

  if (stage.status === 'Complete') {
    classes.push('workflow-step--complete');
  }

  if (!stage.canAccess) {
    classes.push('workflow-step--locked');
  }

  return classes.join(' ');
}

function statusLabel(stage: WorkflowStage) {
  if (stage.status === 'Complete') {
    return 'Complete';
  }

  if (stage.status === 'InProgress') {
    return 'Current';
  }

  return 'Locked';
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
      {snapshot.stages.map((stage) => (
        <li
          className={stepClasses(stage, activeStageId)}
          key={stage.id}
          title={stage.canAccess ? undefined : LOCKED_STAGE_HINT}
        >
          {stage.canAccess ? (
            <Link
              className="workflow-step__link"
              params={{ stageId: stage.id }}
              to="/workflow/$stageId"
            >
              <WorkflowStepContent stage={stage} />
            </Link>
          ) : (
            <button
              aria-disabled="true"
              className="workflow-step__link"
              disabled
              type="button"
            >
              <WorkflowStepContent stage={stage} />
            </button>
          )}
        </li>
      ))}
    </ol>
  );
}

function WorkflowStepContent({ stage }: { stage: WorkflowStage }) {
  return (
    <>
      <span className="workflow-step__number">{stage.number}</span>
      <span className="workflow-step__text">
        <span className="workflow-step__title">{stage.title}</span>
        <span className="text-xs text-slate-500">{statusLabel(stage)}</span>
      </span>
    </>
  );
}
