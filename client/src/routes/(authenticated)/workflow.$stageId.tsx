import {
  canAccessStage,
  getCurrentAvailableStageId,
} from '@/mockData.ts';
import { workflowSnapshotQueryOptions } from '@/queries.ts';
import { DataClassificationStage } from '@/components/dataClassification/DataClassificationStage.tsx';
import { ProjectIdentificationStage } from '@/components/ProjectIdentificationStage.tsx';
import { SectionPanel } from '@/components/SectionPanel.tsx';
import { FlatFileImportPanel } from '@/components/FlatFileImportPanel.tsx';
import { WorkflowShell } from '@/components/WorkflowShell.tsx';
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
          <>
            <SectionPanel title="Load required data">
              <FlatFileImportPanel />
            </SectionPanel>
            <ProjectIdentificationStage />
          </>
        ) : workflowStageId === 'data-classification' ? (
          <DataClassificationStage />
        ) : (
          <SectionPanel title="Coming soon">
            <p>This step is coming soon.</p>
          </SectionPanel>
        )}
      </div>
    </WorkflowShell>
  );
}
