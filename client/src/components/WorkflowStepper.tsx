import type { WorkflowSnapshot, WorkflowStage } from '../types.ts';
import { Link } from '@tanstack/react-router';

function stepClasses(stage: WorkflowStage, activeStageId: string) {
  const classes = ['workflow-step'];

  if (stage.id === activeStageId) {
    classes.push('workflow-step--active');
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
      {snapshot.stages.map((stage) => (
        <li className={stepClasses(stage, activeStageId)} key={stage.id}>
          <Link
            className="workflow-step__link"
            params={{ stageId: stage.id }}
            to="/workflow/$stageId"
          >
            <span className="workflow-step__number">{stage.number}</span>
            <span className="workflow-step__text">
              <span className="workflow-step__title">{stage.title}</span>
            </span>
          </Link>
        </li>
      ))}
    </ol>
  );
}
