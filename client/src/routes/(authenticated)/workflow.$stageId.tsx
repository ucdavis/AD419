import {
  findWorkflowStage,
  WORKFLOW_SNAPSHOT_KEY,
  updateWorkflowStageStatus,
  workflowSnapshotQueryOptions,
} from '@/queries.ts';
import { AutoAssociationsStage } from '@/components/autoAssociations/AutoAssociationsStage.tsx';
import { DataClassificationStage } from '@/components/dataClassification/DataClassificationStage.tsx';
import { DataImportStage } from '@/components/dataImport/DataImportStage.tsx';
import { ExpenseReviewStage } from '@/components/expenseReview/ExpenseReviewStage.tsx';
import { parseExpenseReviewSearch } from '@/components/expenseReview/expenseReviewSearch.ts';
import { OrgRReviewStage } from '@/components/orgrReview/OrgRReviewStage.tsx';
import { ProjectIdentificationStage } from '@/components/ProjectIdentificationStage.tsx';
import { SectionPanel } from '@/components/SectionPanel.tsx';
import { StationSpecialistImportStage } from '@/components/stationSpecialistImport/StationSpecialistImportStage.tsx';
import { WorkflowShell } from '@/components/WorkflowShell.tsx';
import type { WorkflowSnapshot, WorkflowStageId } from '@/types.ts';
import type { RouterContext } from '@/main.tsx';
import {
  createFileRoute,
  Navigate,
  redirect,
  useNavigate,
  useRouter,
  useRouterState,
} from '@tanstack/react-router';
import {
  useMutation,
  useQueryClient,
  useSuspenseQuery,
} from '@tanstack/react-query';

const MANUAL_ASSOCIATIONS_URL = 'https://ad419-next.caes.ucdavis.edu/';

export const Route = createFileRoute('/(authenticated)/workflow/$stageId')({
  validateSearch: parseExpenseReviewSearch,

  // Check access on entry, not on every filter change. React Query owns the data cache.
  component: WorkflowStageRoute,
  errorComponent: WorkflowLoadError,
  gcTime: 0,
  loader: async ({
    context,
    params,
  }: {
    context: RouterContext;
    params: { stageId: string };
  }) => {
    const snapshot = await context.queryClient.fetchQuery({
      ...workflowSnapshotQueryOptions(),
      staleTime: 0,
    });
    const stage = findWorkflowStage(snapshot, params.stageId);

    if (!stage || !stage.canAccess) {
      throw redirect({
        params: { stageId: snapshot.currentStageId },
        to: '/workflow/$stageId',
      });
    }
  },
  pendingComponent: () => <p role="status">Loading workflow...</p>,
  preload: false,
  shouldReload: false,
});

function WorkflowLoadError() {
  const router = useRouter();
  const isLoading = useRouterState({ select: (state) => state.isLoading });

  return (
    <div className="alert alert-error items-start" role="alert">
      <div>
        <h2 className="font-bold">Unable to load workflow status</h2>
        <p>The current workflow step could not be loaded.</p>
        <button
          className="btn btn-sm mt-3"
          disabled={isLoading}
          onClick={() => void router.invalidate()}
          type="button"
        >
          {isLoading ? 'Retrying...' : 'Retry'}
        </button>
      </div>
    </div>
  );
}

function WorkflowStageRoute() {
  const { stageId } = Route.useParams();
  const workflowStageId = stageId as WorkflowStageId;
  const { data: snapshot } = useSuspenseQuery({
    ...workflowSnapshotQueryOptions(),
    refetchOnMount: false,
  });
  const stage = snapshot.stages.find((item) => item.id === workflowStageId);

  if (!stage) {
    return null;
  }

  if (workflowStageId === 'expense-review' && !stage.canAccess) {
    return (
      <Navigate
        params={{ stageId: snapshot.currentStageId }}
        to="/workflow/$stageId"
      />
    );
  }

  return (
    <WorkflowShell snapshot={snapshot} stage={stage}>
      <div className="workflow-stack">
        {workflowStageId === 'project-identification' ? (
          <ProjectIdentificationStage status={stage.status} />
        ) : workflowStageId === 'data-classification' ? (
          <DataClassificationStage status={stage.status} />
        ) : workflowStageId === 'data-import' ? (
          <DataImportStage status={stage.status} />
        ) : workflowStageId === 'expense-review' ? (
          <ExpenseReviewStage />
        ) : workflowStageId === 'station-specialist-import' ? (
          <StationSpecialistImportStage />
        ) : workflowStageId === 'orgr-review' ? (
          <OrgRReviewStage status={stage.status} />
        ) : workflowStageId === 'auto-associations' ? (
          <AutoAssociationsStage status={stage.status} />
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
