import type { WorkflowStage } from '../types.ts';

export function StageHeader({ stage }: { stage: WorkflowStage }) {
  return (
    <section className="workflow-stage-header">
      <div>
        <h1>{stage.title}</h1>
      </div>
    </section>
  );
}
