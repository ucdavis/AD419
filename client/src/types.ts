export type WorkflowStageId =
  | 'project-identification'
  | 'data-import'
  | 'data-classification'
  | 'expense-review'
  | 'orgr-review'
  | 'auto-associations'
  | 'manual-associations'
  | 'post-association-review'
  | 'final-reports';

export interface WorkflowStage {
  canAccess: boolean;
  completedAt: string | null;
  completedByEmail: string | null;
  completedByName: string | null;
  description: string;
  id: WorkflowStageId;
  number: number;
  status: WorkflowStageStatus;
  title: string;
}

export type WorkflowStageStatus = 'Complete' | 'InProgress' | 'NotStarted';

export interface WorkflowSnapshot {
  currentStageId: WorkflowStageId;
  cycleEnd: string;
  cycleStart: string;
  fiscalYear: string;
  stages: WorkflowStage[];
  workflowRunId: number;
}
