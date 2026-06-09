import type { WorkflowSnapshot, WorkflowStage } from '../types.ts';
import type { ReactNode } from 'react';
import { StageHeader } from './StageHeader.tsx';
import { WorkflowStepper } from './WorkflowStepper.tsx';
import { WorkflowTopBar } from './WorkflowTopBar.tsx';

export function WorkflowShell({
  children,
  snapshot,
  stage,
}: {
  children: ReactNode;
  snapshot: WorkflowSnapshot;
  stage: WorkflowStage;
}) {
  return (
    <div className="workflow-app">
      <WorkflowTopBar />
      <WorkflowStepper activeStageId={stage.id} snapshot={snapshot} />
      <main className="workflow-main">
        <StageHeader stage={stage} />
        {children}
      </main>
    </div>
  );
}
