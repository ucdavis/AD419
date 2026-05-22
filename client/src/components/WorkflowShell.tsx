import type { WorkflowSnapshot, WorkflowStage } from '../types.ts';
import type { ReactNode } from 'react';
import { StageHeader } from './StageHeader.tsx';
import { WorkflowStepper } from './WorkflowStepper.tsx';
import { WorkflowTopBar } from './WorkflowTopBar.tsx';

export function WorkflowShell({
  children,
  headerActions,
  snapshot,
  stage,
}: {
  children: ReactNode;
  headerActions?: ReactNode;
  snapshot: WorkflowSnapshot;
  stage: WorkflowStage;
}) {
  return (
    <div className="workflow-app">
      <WorkflowTopBar snapshot={snapshot} />
      <WorkflowStepper activeStageId={stage.id} snapshot={snapshot} />
      <main className="workflow-main">
        <StageHeader
          actions={headerActions}
          snapshot={snapshot}
          stage={stage}
        />
        {children}
      </main>
    </div>
  );
}
