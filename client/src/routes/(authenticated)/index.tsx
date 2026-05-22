import { getCurrentAvailableStageId } from '@/mockData.ts';
import { workflowSnapshotQueryOptions } from '@/queries.ts';
import type { RouterContext } from '@/main.tsx';
import { createFileRoute, redirect } from '@tanstack/react-router';

export const Route = createFileRoute('/(authenticated)/')({
  beforeLoad: async ({ context }: { context: RouterContext }) => {
    const snapshot = await context.queryClient.ensureQueryData(
      workflowSnapshotQueryOptions()
    );

    throw redirect({
      params: { stageId: getCurrentAvailableStageId(snapshot) },
      to: '/workflow/$stageId',
    });
  },
});
