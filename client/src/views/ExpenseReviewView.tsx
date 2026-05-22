import type { WorkflowStagePayload } from '../types.ts';
import { FilterTabs } from '../components/FilterTabs.tsx';
import { MetricStrip } from '../components/MetricStrip.tsx';
import { SectionPanel } from '../components/SectionPanel.tsx';
import {
  WorkflowTable,
  type WorkflowTableColumn,
} from '../components/WorkflowTable.tsx';

type ExpensePayload = Extract<
  WorkflowStagePayload,
  { stageId: 'expense-review' }
>;

const transactionColumns: WorkflowTableColumn<ExpensePayload['rows'][number]>[] =
  [
    {
      header: 'NIFA Project',
      id: 'project',
      render: (row) => <strong>{row.nifaProject}</strong>,
    },
    { header: 'AE', id: 'ae', render: (row) => row.ae },
    { header: 'Dept', id: 'department', render: (row) => row.department },
    { header: 'Fund', id: 'fund', render: (row) => row.fund },
    { header: 'Account', id: 'account', render: (row) => row.account },
    { header: 'Employee', id: 'employee', render: (row) => row.employee },
    { header: 'Source', id: 'source', render: (row) => row.source },
    { header: 'SFN', id: 'sfn', render: (row) => row.sfn },
    {
      align: 'right',
      header: 'Amount',
      id: 'amount',
      render: (row) => row.amount,
    },
    { align: 'right', header: 'FTE', id: 'fte', render: (row) => row.fte },
  ];

const filterChips = [
  'Financial Dept +',
  'Fund +',
  'Account +',
  'AE Project +',
  'NIFA Project +',
  'Source +',
  'SFN +',
];

export function ExpenseReviewView({ payload }: { payload: ExpensePayload }) {
  return (
    <div className="workflow-stack">
      <div className="workflow-stage-copy workflow-stage-copy--split">
        <span>
          Cast a wide net. Only exclude expenses the team is confident should
          not be reported.
        </span>
        <MetricStrip metrics={payload.metrics} />
      </div>

      <SectionPanel
        actions={
          <div className="workflow-action-row workflow-action-row--compact">
            <button className="btn btn-outline btn-sm" type="button">
              Export CSV
            </button>
            <button className="btn btn-ghost btn-sm" type="button">
              Save
            </button>
            <button className="btn btn-primary btn-sm" type="button">
              Continue Step 4
            </button>
          </div>
        }
        title="Expense Transactions"
      >
        <FilterTabs activeId="all" tabs={payload.tabs} />
        <div className="workflow-filter-bar">
          <div className="join">
            <button className="btn btn-sm join-item btn-primary" type="button">
              Included 413,802
            </button>
            <button className="btn btn-sm join-item" type="button">
              Excluded 374,118
            </button>
          </div>
          <div className="workflow-chip-row">
            {filterChips.map((chip) => (
              <button className="btn btn-ghost btn-xs" key={chip} type="button">
                {chip}
              </button>
            ))}
            <button className="btn btn-link btn-xs" type="button">
              Clear all
            </button>
          </div>
        </div>
        <WorkflowTable
          columns={transactionColumns}
          getRowKey={(row) => row.id}
          rows={payload.rows}
        />
      </SectionPanel>
    </div>
  );
}
