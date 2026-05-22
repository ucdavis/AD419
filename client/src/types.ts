export type WorkflowStageId =
  | 'project-identification'
  | 'data-classification'
  | 'expense-review'
  | 'auto-associations'
  | 'post-association-review'
  | 'final-reports';

export type WorkflowStageStatus =
  | 'complete'
  | 'in_progress'
  | 'locked'
  | 'ready';

export interface WorkflowStage {
  description: string;
  id: WorkflowStageId;
  number: number;
  status: WorkflowStageStatus;
  title: string;
}

export interface WorkflowSnapshot {
  activity: {
    actor: string;
    when: string;
  };
  cycle: {
    label: string;
    period: string;
  };
  organization: string;
  stages: WorkflowStage[];
}

export interface StageMetric {
  detail?: string;
  label: string;
  value: string;
}

export interface ChecklistItem {
  detail: string;
  id: string;
  meta?: string;
  status: 'complete' | 'current' | 'pending';
  title: string;
}

export interface FilterTab {
  count?: string;
  id: string;
  label: string;
}

export interface ActionState {
  disabled?: boolean;
  label: string;
  tone?: 'neutral' | 'primary' | 'warning';
}

export interface ProjectIssueRow {
  accession: string;
  ae: string;
  award: string;
  id: string;
  nifaProject: string;
  orgr: string;
  pi: string;
  sfn: string;
  status: string;
}

export interface ClassificationRow {
  code: string;
  hierarchy: string[];
  id: string;
  isNew?: boolean;
  name: string;
  sfn: string;
}

export interface ExpenseTransactionRow {
  account: string;
  ae: string;
  amount: string;
  department: string;
  employee: string;
  fte: string;
  fund: string;
  id: string;
  nifaProject: string;
  sfn: string;
  source: string;
}

export interface StaffTypeRow {
  code: string;
  expense: string;
  fte: string;
  id: string;
  title: string;
}

export interface AssociationRuleRow {
  amount: string;
  id: string;
  logic: string;
  rows: string;
  share: string;
  status: string;
  type: string;
}

export interface ReviewFlagRow {
  id: string;
  pi: string;
  project: string;
  total: string;
}

export interface ReportRow {
  accession: string;
  fte: string;
  id: string;
  pi: string;
  project: string;
  sfn201: string;
  sfn202: string;
  sfn204: string;
  sfn205: string;
  sfn209: string;
  sfn219: string;
  sfn220: string;
  sfn22f: string;
}

export interface DownloadFile {
  detail: string;
  fileName: string;
  id: string;
}

export type WorkflowStagePayload =
  | {
      checklist: ChecklistItem[];
      issues: ProjectIssueRow[];
      metrics: StageMetric[];
      stageId: 'project-identification';
    }
  | {
      rows: ClassificationRow[];
      stageId: 'data-classification';
      tabs: FilterTab[];
    }
  | {
      metrics: StageMetric[];
      rows: ExpenseTransactionRow[];
      stageId: 'expense-review';
      tabs: FilterTab[];
    }
  | {
      rules: AssociationRuleRow[];
      staffTypes: StaffTypeRow[];
      stageId: 'auto-associations';
    }
  | {
      rows: ReviewFlagRow[];
      stageId: 'post-association-review';
      tabs: FilterTab[];
    }
  | {
      downloads: DownloadFile[];
      rows: ReportRow[];
      stageId: 'final-reports';
      tabs: FilterTab[];
    };

export interface WorkflowStageDetails {
  payload: WorkflowStagePayload;
  stage: WorkflowStage;
}
