import { workflowSnapshot } from './mockData.ts';
import { queryOptions } from '@tanstack/react-query';

export const workflowSnapshotQueryOptions = () =>
  queryOptions({
    queryFn: async () => workflowSnapshot,
    queryKey: ['ad419Workflow', 'snapshot'] as const,
  });
