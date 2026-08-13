import { fetchJson } from '@/lib/api.ts';
import type {
  WorkflowSnapshot,
  WorkflowStageId,
  WorkflowStageStatus,
} from '@/types.ts';
import { queryOptions } from '@tanstack/react-query';

export const WORKFLOW_SNAPSHOT_KEY = ['ad419Workflow', 'snapshot'] as const;

export const workflowSnapshotQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) =>
      fetchJson<WorkflowSnapshot>('/api/workflow/snapshot', {}, signal),
    queryKey: WORKFLOW_SNAPSHOT_KEY,
  });

export function findWorkflowStage(snapshot: WorkflowSnapshot, stageId: string) {
  return snapshot.stages.find((stage) => stage.id === stageId);
}

export function updateWorkflowStageStatus(
  stageId: WorkflowStageId,
  status: Extract<WorkflowStageStatus, 'Complete' | 'InProgress'>
) {
  return fetchJson<WorkflowSnapshot>(
    `/api/workflow/stages/${encodeURIComponent(stageId)}`,
    {
      body: JSON.stringify({ status }),
      method: 'PUT',
    }
  );
}
