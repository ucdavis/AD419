import type { WorkflowStagePayload } from '../types.ts';
import { MetricStrip } from '../components/MetricStrip.tsx';
import { SectionPanel } from '../components/SectionPanel.tsx';
import {
  WorkflowTable,
  type WorkflowTableColumn,
} from '../components/WorkflowTable.tsx';

type ProjectPayload = Extract<
  WorkflowStagePayload,
  { stageId: 'project-identification' }
>;

const issueColumns: WorkflowTableColumn<ProjectPayload['issues'][number]>[] = [
  {
    header: 'NIFA Project',
    id: 'project',
    render: (row) => <strong>{row.nifaProject}</strong>,
  },
  { header: 'Accession', id: 'accession', render: (row) => row.accession },
  { header: 'Award #', id: 'award', render: (row) => row.award },
  { header: 'AE', id: 'ae', render: (row) => row.ae },
  { header: 'PI', id: 'pi', render: (row) => row.pi },
  { header: 'ORGR', id: 'orgr', render: (row) => row.orgr },
  { header: 'SFN', id: 'sfn', render: (row) => row.sfn },
  {
    header: 'Status',
    id: 'status',
    render: (row) => <span className="badge badge-warning">{row.status}</span>,
  },
];

export function ProjectIdentificationView({
  payload,
}: {
  payload: ProjectPayload;
}) {
  const completeCount = payload.checklist.filter(
    (item) => item.status === 'complete'
  ).length;

  return (
    <div className="workflow-stack">
      <MetricStrip metrics={payload.metrics} />

      <SectionPanel
        actions={
          <span className="text-sm font-semibold">
            {completeCount} of {payload.checklist.length} complete
          </span>
        }
        eyebrow="Load required data"
        title="Setup Checklist"
      >
        <div className="workflow-checklist">
          {payload.checklist.map((item, index) => (
            <article
              className={`workflow-checklist__item workflow-checklist__item--${item.status}`}
              key={item.id}
            >
              <span className="workflow-checklist__number">
                {item.status === 'complete' ? 'OK' : index + 1}
              </span>
              <div>
                <h3>{item.title}</h3>
                <p>{item.detail}</p>
              </div>
              {item.meta ? <strong>{item.meta}</strong> : null}
            </article>
          ))}
        </div>
        <div className="workflow-warning">
          <strong>7 projects need review in the table below.</strong>
          <span>
            Each issue must be resolved or explicitly accepted before
            finalizing.
          </span>
        </div>
        <div className="workflow-action-row">
          <p>
            Finalizing locks the project list and triggers the full expense
            pull. Approximately 25 min.
          </p>
          <div>
            <button className="btn btn-ghost btn-sm" type="button">
              Save & continue later
            </button>
            <button className="btn btn-outline btn-sm" type="button">
              Mark all projects reviewed
            </button>
            <button className="btn btn-primary btn-sm" type="button">
              Finalize Step 2
            </button>
          </div>
        </div>
      </SectionPanel>

      <SectionPanel
        actions={
          <div className="workflow-inline-filters">
            <span className="badge badge-warning">Issues 7</span>
            <span className="badge badge-success">Clean 18</span>
            <span className="badge">All</span>
          </div>
        }
        eyebrow="Project list - 25"
        title="Reference & Issue Resolution"
      >
        <WorkflowTable
          columns={issueColumns}
          getRowKey={(row) => row.id}
          rows={payload.issues}
        />
      </SectionPanel>
    </div>
  );
}
