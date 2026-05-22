import type { WorkflowStageStatus } from '../types.ts';

const statusLabels: Record<WorkflowStageStatus, string> = {
  complete: 'Complete',
  in_progress: 'In progress',
  locked: 'Locked',
  ready: 'Ready',
};

const statusClasses: Record<WorkflowStageStatus, string> = {
  complete: 'badge-success',
  in_progress: 'badge-warning',
  locked: 'badge-ghost',
  ready: 'badge-info',
};

export function StatusBadge({ status }: { status: WorkflowStageStatus }) {
  return (
    <span className={`badge badge-sm ${statusClasses[status]}`}>
      {statusLabels[status]}
    </span>
  );
}
