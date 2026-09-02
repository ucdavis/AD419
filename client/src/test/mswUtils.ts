import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import { afterAll, afterEach, beforeAll } from 'vitest';
import type {
  WorkflowSnapshot,
  WorkflowStage,
  WorkflowStageId,
  WorkflowStageStatus,
} from '@/types.ts';

const workflowStageDefinitions = [
  {
    description:
      'Load the NIFA project list and resolve any data issues before pulling expenses.',
    id: 'project-identification',
    number: 1,
    title: 'Project Identification',
  },
  {
    description:
      'Pull AE and UCPath transactions for the cycle and seed new chart-string segments for classification.',
    id: 'data-import',
    number: 2,
    title: 'Data Import',
  },
  {
    description:
      'Classify new chart-string segments before they can be included in the AD419 report.',
    id: 'data-classification',
    number: 3,
    title: 'Data Classification',
  },
  {
    description:
      'Confirm the right transactions are included before triggering auto-associations.',
    id: 'expense-review',
    number: 4,
    title: 'Expense Review',
  },
  {
    description:
      'Assign an OrgR to every financial department and NIFA department before associations run.',
    id: 'orgr-review',
    number: 5,
    title: 'OrgR Review',
  },
  {
    description:
      'Run the rules engine to associate as many expenses as possible before manual review.',
    id: 'auto-associations',
    number: 6,
    title: 'Auto-Associations',
  },
  {
    description: 'Complete any associations that require manual review in AD419 Next.',
    id: 'manual-associations',
    number: 7,
    title: 'Manual Associations',
  },
  {
    description:
      'Resolve flagged items after manual associations are complete.',
    id: 'post-association-review',
    number: 8,
    title: 'Post-Association Review',
  },
  {
    description:
      'Generate the final files for ANR submission and cycle signoff.',
    id: 'final-reports',
    number: 9,
    title: 'Final Reports',
  },
] satisfies Array<Pick<WorkflowStage, 'description' | 'id' | 'number' | 'title'>>;

export function createWorkflowSnapshot(
  statuses: Partial<Record<WorkflowStageId, WorkflowStageStatus>> = {}
): WorkflowSnapshot {
  const stages = workflowStageDefinitions.map((definition) => ({
    ...definition,
    canAccess: false,
    completedAt:
      statuses[definition.id] === 'Complete'
        ? '2026-07-07T12:00:00Z'
        : null,
    completedByEmail:
      statuses[definition.id] === 'Complete' ? 'shannon@example.edu' : null,
    completedByName: statuses[definition.id] === 'Complete' ? 'Shannon' : null,
    status: statuses[definition.id] ?? 'NotStarted',
  }));

  if (stages.every((stage) => stage.status === 'NotStarted')) {
    stages[0].status = 'InProgress';
  }

  stages.forEach((stage, index) => {
    const previousComplete = stages
      .slice(0, index)
      .every((candidate) => candidate.status === 'Complete');
    stage.canAccess = stage.status === 'Complete' || previousComplete;
  });

  return {
    currentStageId:
      stages.find((stage) => stage.status !== 'Complete')?.id ??
      'final-reports',
    cycleEnd: '2026-09-30',
    cycleStart: '2025-10-01',
    fiscalYear: 'FY26',
    stages,
    workflowRunId: 1,
  };
}

// Create a shared MSW server instance that can be used across all tests
export const testServer = setupServer(
  http.get('/api/workflow/snapshot', () =>
    HttpResponse.json(createWorkflowSnapshot())
  )
);

// Global setup for MSW server
// This will be automatically called when imported in test files
beforeAll(() => {
  testServer.listen({ onUnhandledRequest: 'error' });
});

afterEach(() => {
  testServer.resetHandlers();
});

afterAll(() => {
  testServer.close();
});

export { testServer as server };
