import type { WorkflowStagePayload } from '../types.ts';
import { FilterTabs } from '../components/FilterTabs.tsx';
import { SectionPanel } from '../components/SectionPanel.tsx';
import {
  WorkflowTable,
  type WorkflowTableColumn,
} from '../components/WorkflowTable.tsx';

type ReviewPayload = Extract<
  WorkflowStagePayload,
  { stageId: 'post-association-review' }
>;

const reviewColumns: WorkflowTableColumn<ReviewPayload['rows'][number]>[] = [
  {
    header: 'Project',
    id: 'project',
    render: (row) => <strong>{row.project}</strong>,
  },
  { header: 'PI', id: 'pi', render: (row) => row.pi },
  { align: 'right', header: 'Total', id: 'total', render: (row) => row.total },
  {
    header: '',
    id: 'action',
    render: () => (
      <button className="btn btn-outline btn-xs" type="button">
        Confirm
      </button>
    ),
  },
];

export function PostAssociationReviewView({
  payload,
}: {
  payload: ReviewPayload;
}) {
  return (
    <div className="workflow-stack">
      <div className="workflow-stage-copy">
        Sanity checks after manual associations are complete. Resolve flagged
        items before generating final reports.
      </div>
      <SectionPanel
        actions={
          <button className="btn btn-outline btn-sm" type="button">
            Re-add &lt;$100 projects
          </button>
        }
        title="Sanity Checks"
      >
        <FilterTabs activeId="under-100" tabs={payload.tabs} />
        <p className="workflow-panel-note">
          Excluded from associations but re-added to the final report.
        </p>
        <WorkflowTable
          columns={reviewColumns}
          getRowKey={(row) => row.id}
          rows={payload.rows}
        />
      </SectionPanel>
    </div>
  );
}
