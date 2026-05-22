import {
  canAccessStage,
  getCurrentAvailableStageId,
} from '@/mockData.ts';
import {
  workflowSnapshotQueryOptions,
  workflowStageQueryOptions,
} from '@/queries.ts';
import { WorkflowShell } from '@/components/WorkflowShell.tsx';
import { WorkflowStageView } from '@/views/WorkflowStageView.tsx';
import type { WorkflowStageId } from '@/types.ts';
import type { RouterContext } from '@/main.tsx';
import { createFileRoute, redirect } from '@tanstack/react-router';
import { useSuspenseQuery } from '@tanstack/react-query';

export const Route = createFileRoute('/(authenticated)/workflow/$stageId')({
  beforeLoad: async ({
    context,
    params,
  }: {
    context: RouterContext;
    params: { stageId: string };
  }) => {
    const snapshot = await context.queryClient.ensureQueryData(
      workflowSnapshotQueryOptions()
    );

    if (!canAccessStage(params.stageId)) {
      throw redirect({
        params: { stageId: getCurrentAvailableStageId(snapshot) },
        to: '/workflow/$stageId',
      });
    }

    await context.queryClient.ensureQueryData(
      workflowStageQueryOptions(params.stageId)
    );
  },
  component: WorkflowStageRoute,
});

function getHeaderActions(stageId: WorkflowStageId) {
  switch (stageId) {
    case 'auto-associations':
      return (
        <button className="btn btn-outline btn-sm" type="button">
          View association detail
        </button>
      );
    case 'data-classification':
      return (
        <button className="btn btn-primary btn-sm" type="button">
          Continue Step 3
        </button>
      );
    case 'expense-review':
      return (
        <button className="btn btn-primary btn-sm" type="button">
          Continue Step 4
        </button>
      );
    case 'final-reports':
      return (
        <button className="btn btn-primary btn-sm" type="button">
          Submit to ANR
        </button>
      );
    case 'post-association-review':
      return (
        <button className="btn btn-primary btn-sm" type="button">
          Continue Step 6
        </button>
      );
    case 'project-identification':
      return (
        <button className="btn btn-primary btn-sm" type="button">
          Finalize Step 2
        </button>
      );
  }
}

function WorkflowStageRoute() {
  const { stageId } = Route.useParams();
  const workflowStageId = stageId as WorkflowStageId;
  const { data: snapshot } = useSuspenseQuery(workflowSnapshotQueryOptions());
  const { data: stageDetails } = useSuspenseQuery(
    workflowStageQueryOptions(workflowStageId)
  );

  return (
    <WorkflowShell
      headerActions={getHeaderActions(workflowStageId)}
      snapshot={snapshot}
      stage={stageDetails.stage}
    >
      <WorkflowStageView payload={stageDetails.payload} />
    </WorkflowShell>
  );
}
