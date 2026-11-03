import { fetchJson } from '@/lib/api.ts';
import type { WorkflowStageId } from '@/types.ts';
import { queryOptions } from '@tanstack/react-query';

export interface StageDocumentation {
  embedUrl: string;
  url: string;
}

export const stageDocumentationQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) =>
      fetchJson<Partial<Record<WorkflowStageId, StageDocumentation>>>(
        '/api/workflow/documentation',
        { skipRedirectOn401: true },
        signal
      ),
    queryKey: ['workflowDocumentation'],
    retry: false,
    staleTime: Infinity,
  });
