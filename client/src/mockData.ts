import type {
  WorkflowSnapshot,
  WorkflowStage,
  WorkflowStageId,
} from './types.ts';

export const workflowStages: WorkflowStage[] = [
  {
    canAccess: true,
    completedAt: null,
    completedByEmail: null,
    completedByName: null,
    description:
      'Load the NIFA project list and resolve any data issues before pulling expenses.',
    id: 'project-identification',
    number: 1,
    status: 'InProgress',
    title: 'Project Identification',
  },
  {
    canAccess: false,
    completedAt: null,
    completedByEmail: null,
    completedByName: null,
    description:
      'Pull AE and UCPath transactions for the cycle and seed new chart-string segments for classification.',
    id: 'data-import',
    number: 2,
    status: 'NotStarted',
    title: 'Data Import',
  },
  {
    canAccess: false,
    completedAt: null,
    completedByEmail: null,
    completedByName: null,
    description:
      'Classify new chart-string segments before they can be included in the AD419 report.',
    id: 'data-classification',
    number: 3,
    status: 'NotStarted',
    title: 'Data Classification',
  },
  {
    canAccess: false,
    completedAt: null,
    completedByEmail: null,
    completedByName: null,
    description:
      'Confirm the right transactions are included before triggering auto-associations.',
    id: 'expense-review',
    number: 4,
    status: 'NotStarted',
    title: 'Expense Review',
  },
  {
    canAccess: false,
    completedAt: null,
    completedByEmail: null,
    completedByName: null,
    description:
      'Run the rules engine to associate as many expenses as possible before manual review.',
    id: 'auto-associations',
    number: 5,
    status: 'NotStarted',
    title: 'Auto-Associations',
  },
  {
    canAccess: false,
    completedAt: null,
    completedByEmail: null,
    completedByName: null,
    description:
      'Resolve flagged items after manual associations are complete.',
    id: 'post-association-review',
    number: 6,
    status: 'NotStarted',
    title: 'Post-Association Review',
  },
  {
    canAccess: false,
    completedAt: null,
    completedByEmail: null,
    completedByName: null,
    description:
      'Import Field Station and CE Specialists data before generating final reports.',
    id: 'station-specialist-import',
    number: 7,
    status: 'NotStarted',
    title: 'Station/Specialist Import',
  },
  {
    canAccess: false,
    completedAt: null,
    completedByEmail: null,
    completedByName: null,
    description:
      'Generate the final files for ANR submission and cycle signoff.',
    id: 'final-reports',
    number: 8,
    status: 'NotStarted',
    title: 'Final Reports',
  },
];

export const workflowSnapshot: WorkflowSnapshot = {
  currentStageId: 'project-identification',
  cycleEnd: '2026-09-30',
  cycleStart: '2025-10-01',
  fiscalYear: 'FY26',
  stages: workflowStages,
  workflowRunId: 1,
};

export function findWorkflowStage(stageId: string): WorkflowStage | undefined {
  return workflowStages.find((stage) => stage.id === stageId);
}

export function getCurrentAvailableStageId(
  snapshot: WorkflowSnapshot
): WorkflowStageId {
  return snapshot.currentStageId;
}

export function canAccessStage(stageId: string): stageId is WorkflowStageId {
  return Boolean(findWorkflowStage(stageId));
}
