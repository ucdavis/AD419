import { SectionPanel } from '@/components/SectionPanel.tsx';
import {
  bufferedImportWindow,
  importRunQueryOptions,
  startImportRun,
} from '@/queries/importRuns.ts';
import {
  projectIdentificationSetupQueryOptions,
  type ProjectIdentificationSetupResponse,
} from '@/queries/projectIdentification.ts';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { ImportRunStage } from '@/queries/importRuns.ts';

const STATUS_BADGES: Record<ImportRunStage['status'], string> = {
  Failed: 'badge badge-error badge-outline',
  Pending: 'badge badge-ghost',
  Running: 'badge badge-info',
  Succeeded: 'badge badge-success badge-outline',
};

export function DataImportStage() {
  const setupQuery = useQuery(projectIdentificationSetupQueryOptions());

  if (setupQuery.isLoading) {
    return <p>Loading data import...</p>;
  }

  if (setupQuery.isError || !setupQuery.data) {
    return (
      <div className="alert alert-error items-start" role="alert">
        <div>
          <h2 className="font-bold">Unable to load reporting cycle</h2>
          <p>
            The fiscal period from Project Identification could not be loaded.
          </p>
          <button
            className="btn btn-sm mt-3"
            disabled={setupQuery.isFetching}
            onClick={() => void setupQuery.refetch()}
            type="button"
          >
            {setupQuery.isFetching ? 'Retrying...' : 'Retry'}
          </button>
        </div>
      </div>
    );
  }

  return <DataImportStageContent setup={setupQuery.data} />;
}

function DataImportStageContent({
  setup,
}: {
  setup: ProjectIdentificationSetupResponse;
}) {
  const queryClient = useQueryClient();
  const { data: run } = useQuery(importRunQueryOptions());

  const start = useMutation({
    mutationFn: startImportRun,
    onSuccess: (created) => {
      queryClient.setQueryData(importRunQueryOptions().queryKey, created);
    },
  });

  const periodLabel =
    setup.fiscalPeriodOptions.find(
      (option) => option.fiscalYear === setup.fiscalYear
    )?.label ?? '';
  const { windowEnd, windowStart } = bufferedImportWindow(
    setup.cycleStart,
    setup.cycleEnd
  );

  const isRunning = run?.status === 'Running' || start.isPending;
  const failedStages =
    run?.stages.filter((stage) => stage.status === 'Failed') ?? [];
  const sortedStages = [...(run?.stages ?? [])].sort(
    (a, b) => a.ordinal - b.ordinal
  );

  return (
    <SectionPanel eyebrow="Expense Data" title="Data Import">
      <div className="space-y-4 p-4">
        <p className="text-sm text-slate-600">
          Pulls AE and UCPath transactions for the reporting cycle and seeds
          new chart string segments for classification. The fiscal year comes
          from the Project Identification step. Pulling in transactions may
          take several hours, and the import keeps running in the background
          if you leave this page.
        </p>

        <div className="grid gap-3 lg:grid-cols-2">
          <label className="form-control w-full">
            <span className="label-text">Fiscal year</span>
            <select
              className="select select-bordered w-full"
              disabled
              value={setup.fiscalYear}
            >
              <option value={setup.fiscalYear}>
                {setup.fiscalYear.replace('FY', 'FY:')}
              </option>
            </select>
          </label>

          <label className="form-control w-full">
            <span className="label-text">Period</span>
            <select
              className="select select-bordered w-full"
              disabled
              value={periodLabel}
            >
              <option>{periodLabel}</option>
            </select>
          </label>
        </div>

        <p className="text-sm text-slate-600">
          Transactions are imported for {formatDate(windowStart)} through{' '}
          {formatDate(windowEnd)}, the fiscal year with a 3 month buffer on
          each end. We intentionally cast a wide net to make sure we&apos;re
          pulling in all relevant transactions. Transactions from outside the
          fiscal year will be excluded for the final report.
        </p>

        <div className="flex justify-end">
          <button
            className="btn btn-primary"
            disabled={isRunning}
            onClick={() =>
              start.mutate({
                cycleEnd: setup.cycleEnd,
                cycleStart: setup.cycleStart,
              })
            }
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
            <div className="flex flex-wrap items-center gap-4 text-sm text-slate-600">
              <span className={STATUS_BADGES[run.status]}>{run.status}</span>
              <span>
                Cycle {formatDate(run.cycleStart)} through{' '}
                {formatDate(run.cycleEnd)}
              </span>
              {run.triggeredByName ? (
                <span>Triggered by {run.triggeredByName}</span>
              ) : null}
              <span>Started {formatDateTime(run.startedAt)}</span>
              {run.completedAt ? (
                <span>Completed {formatDateTime(run.completedAt)}</span>
              ) : null}
            </div>

            <table className="table table-zebra table-sm">
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
                      <span className={STATUS_BADGES[stage.status]}>
                        {stage.status}
                      </span>
                    </td>
                    <td>{stage.detail ?? stage.rowCount?.toLocaleString() ?? '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="rounded border border-dashed border-slate-300 bg-slate-50 p-8 text-center text-slate-600">
            No import has run yet for this cycle.
          </div>
        )}
      </div>
    </SectionPanel>
  );
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeZone: 'UTC',
  }).format(new Date(`${value}T00:00:00Z`));
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}
