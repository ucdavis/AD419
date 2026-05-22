import type { WorkflowStagePayload } from '../types.ts';
import { SectionPanel } from '../components/SectionPanel.tsx';
import {
  WorkflowTable,
  type WorkflowTableColumn,
} from '../components/WorkflowTable.tsx';

type AutoPayload = Extract<
  WorkflowStagePayload,
  { stageId: 'auto-associations' }
>;

const staffColumns: WorkflowTableColumn<AutoPayload['staffTypes'][number]>[] = [
  { header: 'Code', id: 'code', render: (row) => <strong>{row.code}</strong> },
  { header: 'Title', id: 'title', render: (row) => row.title },
  { align: 'right', header: 'Expense', id: 'expense', render: (row) => row.expense },
  { align: 'right', header: 'FTE', id: 'fte', render: (row) => row.fte },
  {
    header: '',
    id: 'action',
    render: () => (
      <button className="btn btn-outline btn-xs" type="button">
        Choose staff type
      </button>
    ),
  },
];

const ruleColumns: WorkflowTableColumn<AutoPayload['rules'][number]>[] = [
  { header: 'Type', id: 'type', render: (row) => <strong>{row.type}</strong> },
  { header: 'Logic', id: 'logic', render: (row) => row.logic },
  { align: 'right', header: 'Rows', id: 'rows', render: (row) => row.rows },
  { align: 'right', header: 'Amount', id: 'amount', render: (row) => row.amount },
  { align: 'right', header: 'Share', id: 'share', render: (row) => row.share },
  {
    header: 'Status',
    id: 'status',
    render: (row) => <span className="badge badge-ghost">{row.status}</span>,
  },
];

export function AutoAssociationsView({ payload }: { payload: AutoPayload }) {
  return (
    <div className="workflow-stack">
      <div className="workflow-stage-copy">
        Run the rules engine to associate as many expenses as possible before
        sending the rest to the manual associations app.
      </div>

      <SectionPanel
        eyebrow="Title codes drive FTE SFN assignment"
        title="3 title codes need a staff type"
      >
        <div className="workflow-warning workflow-warning--blocking">
          <strong>Staff type is required before auto-associations can run.</strong>
          <span>
            These title codes appear in UCP salary expenses and need an explicit
            classification.
          </span>
        </div>
        <WorkflowTable
          columns={staffColumns}
          getRowKey={(row) => row.id}
          rows={payload.staffTypes}
        />
      </SectionPanel>

      <SectionPanel
        actions={
          <span className="text-sm font-semibold">
            Will associate 13,969 rows - $41,773,490
          </span>
        }
        eyebrow="Auto-association rules"
        title="Preview"
      >
        <WorkflowTable
          columns={ruleColumns}
          getRowKey={(row) => row.id}
          rows={payload.rules}
        />
        <div className="workflow-action-row">
          <p>Remaining for manual association: about 58% - $30.4M.</p>
          <button className="btn btn-primary" type="button">
            Run auto-associations
          </button>
        </div>
      </SectionPanel>
    </div>
  );
}
