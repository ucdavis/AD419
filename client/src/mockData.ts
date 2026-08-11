import type {
  WorkflowSnapshot,
  WorkflowStage,
  WorkflowStageId,
} from './types.ts';

export const workflowStages: WorkflowStage[] = [
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
      'Run the rules engine to associate as many expenses as possible before manual review.',
    id: 'auto-associations',
    number: 5,
    title: 'Auto-Associations',
  },
  {
    description:
      'Resolve flagged items after manual associations are complete.',
    id: 'post-association-review',
    number: 6,
    title: 'Post-Association Review',
  },
  {
    description:
      'Generate the final files for ANR submission and cycle signoff.',
    id: 'final-reports',
    number: 7,
    title: 'Final Reports',
  },
];

export const workflowSnapshot: WorkflowSnapshot = {
  stages: workflowStages,
};

export function findWorkflowStage(stageId: string): WorkflowStage | undefined {
  return workflowStages.find((stage) => stage.id === stageId);
}

export function getCurrentAvailableStageId(
  snapshot: WorkflowSnapshot
): WorkflowStageId {
  return snapshot.stages[0].id;
}

export function canAccessStage(stageId: string): stageId is WorkflowStageId {
  return Boolean(findWorkflowStage(stageId));
}
