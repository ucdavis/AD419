export type WorkflowStageId =
  | 'project-identification'
  | 'data-classification'
  | 'expense-review'
  | 'auto-associations'
  | 'post-association-review'
  | 'final-reports';

export interface WorkflowStage {
  description: string;
  id: WorkflowStageId;
  number: number;
  title: string;
}

export interface WorkflowSnapshot {
  stages: WorkflowStage[];
}
