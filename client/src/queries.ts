import {
  findWorkflowStageDetails,
  workflowSnapshot,
} from './mockData.ts';
import type { WorkflowStageId } from './types.ts';
import { queryOptions } from '@tanstack/react-query';

export const workflowSnapshotQueryOptions = () =>
  queryOptions({
    queryFn: async () => workflowSnapshot,
    queryKey: ['ad419Workflow', 'snapshot'] as const,
  });

export const workflowStageQueryOptions = (stageId: WorkflowStageId) =>
  queryOptions({
    queryFn: async () => {
      const stageDetails = findWorkflowStageDetails(stageId);

      if (!stageDetails) {
        throw new Error(`Unknown workflow stage: ${stageId}`);
      }

      return stageDetails;
    },
    queryKey: ['ad419Workflow', 'stage', stageId] as const,
  });
