import type { WorkflowStagePayload } from '../types.ts';
import { AutoAssociationsView } from './AutoAssociationsView.tsx';
import { DataClassificationView } from './DataClassificationView.tsx';
import { ExpenseReviewView } from './ExpenseReviewView.tsx';
import { FinalReportsView } from './FinalReportsView.tsx';
import { PostAssociationReviewView } from './PostAssociationReviewView.tsx';
import { ProjectIdentificationView } from './ProjectIdentificationView.tsx';

export function WorkflowStageView({
  payload,
}: {
  payload: WorkflowStagePayload;
}) {
  switch (payload.stageId) {
    case 'auto-associations':
      return <AutoAssociationsView payload={payload} />;
    case 'data-classification':
      return <DataClassificationView payload={payload} />;
    case 'expense-review':
      return <ExpenseReviewView payload={payload} />;
    case 'final-reports':
      return <FinalReportsView payload={payload} />;
    case 'post-association-review':
      return <PostAssociationReviewView payload={payload} />;
    case 'project-identification':
      return <ProjectIdentificationView payload={payload} />;
  }
}
