import type { WorkflowStagePayload } from '../types.ts';
import { FilterTabs } from '../components/FilterTabs.tsx';
import { SectionPanel } from '../components/SectionPanel.tsx';
import {
  WorkflowTable,
  type WorkflowTableColumn,
} from '../components/WorkflowTable.tsx';

type ClassificationPayload = Extract<
  WorkflowStagePayload,
  { stageId: 'data-classification' }
>;

const classificationColumns: WorkflowTableColumn<
  ClassificationPayload['rows'][number]
>[] = [
  {
    header: 'Fund',
    id: 'fund',
    render: (row) => (
      <strong>
        {row.code}
        {row.isNew ? <span className="workflow-new-label">NEW</span> : null}
      </strong>
    ),
  },
  { header: 'Name', id: 'name', render: (row) => row.name },
  {
    header: 'Hierarchy',
    id: 'hierarchy',
    render: (row) => (
      <div className="workflow-hierarchy">
        {row.hierarchy.map((value) => (
          <span key={value}>{value}</span>
        ))}
      </div>
    ),
  },
  {
    header: 'SFN',
    id: 'sfn',
    render: (row) => (
      <span
        className={
          row.sfn === 'Unset' ? 'badge badge-warning' : 'badge badge-ghost'
        }
      >
        {row.sfn}
      </span>
    ),
  },
  {
    header: '',
    id: 'action',
    render: (row) =>
      row.sfn === 'Unset' ? (
        <button className="btn btn-outline btn-xs" type="button">
          Classify
        </button>
      ) : null,
  },
];

export function DataClassificationView({
  payload,
}: {
  payload: ClassificationPayload;
}) {
  return (
    <div className="workflow-stack">
      <div className="workflow-stage-copy">
        New chart-string segments need to be classified before they can be
        included or excluded from the AD419 report. Year-over-year persisted
        classifications are pre-filled.
      </div>
      <SectionPanel
        actions={
          <div className="workflow-action-row workflow-action-row--compact">
            <button className="btn btn-ghost btn-sm" type="button">
              Save
            </button>
            <button className="btn btn-primary btn-sm" type="button">
              Continue Step 3
            </button>
          </div>
        }
        title="Classifications"
      >
        <FilterTabs activeId="fund" tabs={payload.tabs} />
        <WorkflowTable
          columns={classificationColumns}
          getRowKey={(row) => row.id}
          rows={payload.rows}
        />
      </SectionPanel>
    </div>
  );
}
