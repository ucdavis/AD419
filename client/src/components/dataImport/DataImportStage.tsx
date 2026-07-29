import { SectionPanel } from '@/components/SectionPanel.tsx';
import {
  defaultCycleDates,
  importRunQueryOptions,
  startImportRun,
} from '@/queries/importRuns.ts';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import type { ImportRunStage } from '@/queries/importRuns.ts';

const STATUS_BADGES: Record<ImportRunStage['status'], string> = {
  Failed: 'badge-error',
  Pending: 'badge-ghost',
  Running: 'badge-info',
  Succeeded: 'badge-success',
};

export function DataImportStage() {
  const queryClient = useQueryClient();
  const { data: run } = useQuery(importRunQueryOptions());
  const defaults = defaultCycleDates();
  const [cycleStart, setCycleStart] = useState(defaults.cycleStart);
  const [cycleEnd, setCycleEnd] = useState(defaults.cycleEnd);

  const start = useMutation({
    mutationFn: startImportRun,
    onSuccess: (created) => {
      queryClient.setQueryData(importRunQueryOptions().queryKey, created);
    },
  });

  const isRunning = run?.status === 'Running' || start.isPending;
  const failedStages = run?.stages.filter((stage) => stage.status === 'Failed') ?? [];
  const sortedStages = [...(run?.stages ?? [])].sort(
    (a, b) => a.ordinal - b.ordinal
  );

  return (
    <SectionPanel title="Data Import">
      <div className="space-y-4">
        <p>
          Pull AE and UCPath transactions for the reporting cycle and seed new
          chart-string segments for classification.
        </p>

        <div className="flex flex-wrap items-end gap-4">
          <label className="form-control">
            <span className="label-text">Cycle start</span>
            <input
              className="input input-bordered"
              disabled={isRunning}
              onChange={(event) => setCycleStart(event.target.value)}
              type="date"
              value={cycleStart}
            />
          </label>
          <label className="form-control">
            <span className="label-text">Cycle end</span>
            <input
              className="input input-bordered"
              disabled={isRunning}
              onChange={(event) => setCycleEnd(event.target.value)}
              type="date"
              value={cycleEnd}
            />
          </label>
          <button
            className="btn btn-primary"
            disabled={isRunning}
            onClick={() => start.mutate({ cycleEnd, cycleStart })}
            type="button"
          >
            Start Import
          </button>
        </div>

        {start.error ? (
          <div className="alert alert-error" role="alert">
            <span>
              {start.error instanceof Error
                ? start.error.message
                : 'Failed to start the import.'}
            </span>
          </div>
        ) : null}

        {failedStages.map((stage) => (
          <div className="alert alert-error" key={stage.ordinal} role="alert">
            <span>
              {stage.name}: {stage.errorDetail}
            </span>
          </div>
        ))}

        {run ? (
          <div className="space-y-2">
            <div className="flex flex-wrap items-center gap-4 text-sm">
              <span className={`badge ${STATUS_BADGES[run.status]}`}>
                {run.status}
              </span>
              <span>
                Cycle {run.cycleStart} to {run.cycleEnd}
              </span>
              {run.triggeredByName ? (
                <span>Triggered by {run.triggeredByName}</span>
              ) : null}
              <span>Started {run.startedAt}</span>
              {run.completedAt ? <span>Completed {run.completedAt}</span> : null}
            </div>

            <table className="table">
              <thead>
                <tr>
                  <th>Stage</th>
                  <th>Status</th>
                  <th>Rows</th>
                </tr>
              </thead>
              <tbody>
                {sortedStages.map((stage) => (
                  <tr key={stage.ordinal}>
                    <td>{stage.name}</td>
                    <td>
                      <span className={`badge ${STATUS_BADGES[stage.status]}`}>
                        {stage.status}
                      </span>
                    </td>
                    <td>{stage.rowCount?.toLocaleString() ?? '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p>No import has run yet for this cycle.</p>
        )}
      </div>
    </SectionPanel>
  );
}
