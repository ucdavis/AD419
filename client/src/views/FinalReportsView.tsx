import type { WorkflowStagePayload } from '../types.ts';
import { DownloadCard } from '../components/DownloadCard.tsx';
import { FilterTabs } from '../components/FilterTabs.tsx';
import { SectionPanel } from '../components/SectionPanel.tsx';
import {
  WorkflowTable,
  type WorkflowTableColumn,
} from '../components/WorkflowTable.tsx';

type ReportsPayload = Extract<
  WorkflowStagePayload,
  { stageId: 'final-reports' }
>;

const reportColumns: WorkflowTableColumn<ReportsPayload['rows'][number]>[] = [
  {
    header: 'Project',
    id: 'project',
    render: (row) => <strong>{row.project}</strong>,
  },
  { header: 'Accession', id: 'accession', render: (row) => row.accession },
  { header: 'PI', id: 'pi', render: (row) => row.pi },
  { align: 'right', header: '201', id: '201', render: (row) => row.sfn201 },
  { align: 'right', header: '202', id: '202', render: (row) => row.sfn202 },
  { align: 'right', header: '204', id: '204', render: (row) => row.sfn204 },
  { align: 'right', header: '205', id: '205', render: (row) => row.sfn205 },
  { align: 'right', header: '209', id: '209', render: (row) => row.sfn209 },
  { align: 'right', header: '219', id: '219', render: (row) => row.sfn219 },
  { align: 'right', header: '220', id: '220', render: (row) => row.sfn220 },
  { align: 'right', header: '22F', id: '22f', render: (row) => row.sfn22f },
  { align: 'right', header: 'FTE', id: 'fte', render: (row) => row.fte },
];

export function FinalReportsView({ payload }: { payload: ReportsPayload }) {
  return (
    <div className="workflow-stack">
      <div className="workflow-stage-copy">
        Aggregated by NIFA project x SFN. Admin expenses are prorated,
        negatives are floored to zero, dollar amounts are rounded to the nearest
        dollar, and FTE is rounded to 0.1.
      </div>
      <SectionPanel
        actions={
          <div className="workflow-action-row workflow-action-row--compact">
            <span className="text-sm font-semibold">
              Total cycle $2,833,856 - 14.8 FTE
            </span>
            <button className="btn btn-outline btn-sm" type="button">
              Preview ANR files
            </button>
            <button className="btn btn-primary btn-sm" type="button">
              Export 4 ANR files
            </button>
          </div>
        }
        title="Report Preview"
      >
        <FilterTabs activeId="admin" tabs={payload.tabs} />
        <WorkflowTable
          columns={reportColumns}
          getRowKey={(row) => row.id}
          rows={payload.rows}
        />
      </SectionPanel>
      <div className="workflow-download-grid">
        {payload.downloads.map((file) => (
          <DownloadCard file={file} key={file.id} />
        ))}
      </div>
    </div>
  );
}
