import {
  findWorkflowStage,
  WORKFLOW_SNAPSHOT_KEY,
  updateWorkflowStageStatus,
  workflowSnapshotQueryOptions,
} from '@/queries.ts';
import { DataClassificationStage } from '@/components/dataClassification/DataClassificationStage.tsx';
import { DataImportStage } from '@/components/dataImport/DataImportStage.tsx';
import { ProjectIdentificationStage } from '@/components/ProjectIdentificationStage.tsx';
import { SectionPanel } from '@/components/SectionPanel.tsx';
import { WorkflowShell } from '@/components/WorkflowShell.tsx';
import type { WorkflowSnapshot, WorkflowStageId } from '@/types.ts';
import type { RouterContext } from '@/main.tsx';
import { createFileRoute, redirect, useNavigate } from '@tanstack/react-router';
import {
  useMutation,
  useQueryClient,
  useSuspenseQuery,
} from '@tanstack/react-query';

const MANUAL_ASSOCIATIONS_URL = 'https://ad419-next.caes.ucdavis.edu/';

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
    const stage = findWorkflowStage(snapshot, params.stageId);

    if (!stage || !stage.canAccess) {
      throw redirect({
        params: { stageId: snapshot.currentStageId },
        to: '/workflow/$stageId',
      });
    }
  },
  component: WorkflowStageRoute,
});

function WorkflowStageRoute() {
  const { stageId } = Route.useParams();
  const workflowStageId = stageId as WorkflowStageId;
  const { data: snapshot } = useSuspenseQuery(workflowSnapshotQueryOptions());
  const stage = snapshot.stages.find((item) => item.id === workflowStageId);

  if (!stage) {
    return null;
  }

  return (
    <WorkflowShell snapshot={snapshot} stage={stage}>
      <div className="workflow-stack">
        {workflowStageId === 'project-identification' ? (
          <ProjectIdentificationStage />
        ) : workflowStageId === 'data-classification' ? (
          <DataClassificationStage />
        ) : workflowStageId === 'data-import' ? (
          <DataImportStage />
        ) : (
          <PlaceholderWorkflowStage
            snapshot={snapshot}
            stageId={workflowStageId}
          />
        )}
      </div>
    </WorkflowShell>
  );
}

function PlaceholderWorkflowStage({
  snapshot,
  stageId,
}: {
  snapshot: WorkflowSnapshot;
  stageId: WorkflowStageId;
}) {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const stage = findWorkflowStage(snapshot, stageId);
  const nextStage = snapshot.stages.find(
    (candidate) => candidate.number === (stage?.number ?? 0) + 1
  );
  const isManualAssociations = stageId === 'manual-associations';
  const continueMutation = useMutation({
    mutationFn: () => updateWorkflowStageStatus(stageId, 'Complete'),
    onSuccess: (updatedSnapshot) => {
      queryClient.setQueryData(WORKFLOW_SNAPSHOT_KEY, updatedSnapshot);
      void navigate({
        params: { stageId: updatedSnapshot.currentStageId },
        to: '/workflow/$stageId',
      });
    },
  });

  return (
    <SectionPanel
      actions={
        stage?.status === 'Complete' ? null : (
          <button
            className="btn btn-primary"
            disabled={continueMutation.isPending}
            onClick={() => continueMutation.mutate()}
            type="button"
          >
            {continueMutation.isPending
              ? 'Continuing...'
              : nextStage
                ? `Continue to ${nextStage.title}`
                : 'Complete Workflow'}
          </button>
        )
      }
      title={isManualAssociations ? 'Manual Associations' : 'Coming soon'}
    >
      {isManualAssociations ? (
        <p>
          <a
            className="link link-primary font-semibold"
            href={MANUAL_ASSOCIATIONS_URL}
            rel="noreferrer"
            target="_blank"
          >
            Open AD419 Next
          </a>
        </p>
      ) : (
        <p>This step is coming soon.</p>
      )}
      {continueMutation.isError ? (
        <div className="alert alert-error mt-4" role="alert">
          <span>
            {continueMutation.error instanceof Error
              ? continueMutation.error.message
              : 'Could not update the workflow stage.'}
          </span>
        </div>
      ) : null}
    </SectionPanel>
  );
}
