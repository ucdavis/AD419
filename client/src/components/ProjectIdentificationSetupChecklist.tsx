import {
  confirmFiscalPeriod,
  setChecklistItemCompletion,
  type ProjectChecklistItem,
  type ProjectIdentificationSetupResponse,
} from '@/queries/projectIdentification.ts';
import {
  FlatFileImportChecklistItem,
  type ImportDatasetId,
} from '@/components/FlatFileImportPanel.tsx';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { fetchJson } from '@/lib/api.ts';

interface PgmImportResponse {
  reportDate: string;
  rowsImported: number;
}

export function ProjectIdentificationSetupChecklist({
  issueCount,
  setup,
}: {
  issueCount: number | null;
  setup: ProjectIdentificationSetupResponse;
}) {
  const queryClient = useQueryClient();
  const firstIncompleteId = useMemo(
    () => setup.checklistItems.find((item) => !item.completed)?.id ?? null,
    [setup.checklistItems]
  );
  const [openItemId, setOpenItemId] = useState<string | null>(
    firstIncompleteId
  );

  const markCompletionMutation = useMutation({
    mutationFn: ({
      completed,
      itemId,
    }: {
      completed: boolean;
      itemId: string;
    }) => setChecklistItemCompletion(itemId, completed),
    onSuccess: (response) => {
      queryClient.setQueryData(['projectIdentification', 'setup'], response);
      setOpenItemId(findFirstIncompleteItemId(response));
      void queryClient.invalidateQueries({ queryKey: ['projectList'] });
    },
  });

  const fiscalMutation = useMutation({
    mutationFn: confirmFiscalPeriod,
    onSuccess: (response) => {
      queryClient.setQueryData(['projectIdentification', 'setup'], response);
      setOpenItemId(findFirstIncompleteItemId(response));
      void queryClient.invalidateQueries({ queryKey: ['projectList'] });
    },
  });

  const handleMarkDone = (itemId: string) => {
    markCompletionMutation.mutate({ completed: true, itemId });
  };

  return (
    <section className="workflow-panel">
      <div className="workflow-panel__header">
        <div>
          <p>Setup checklist</p>
          <h2>Load required data</h2>
        </div>
        <div className="min-w-40 space-y-2 text-right">
          <div className="text-sm text-slate-500">
            {setup.completedCount} of {setup.totalCount} complete
          </div>
          <progress
            className="progress progress-neutral h-1.5 w-40"
            max={setup.totalCount}
            value={setup.completedCount}
          />
        </div>
      </div>

      <div className="divide-y divide-slate-200">
        {setup.checklistItems.map((item) => {
          const locked = item.status === 'locked';
          const open = openItemId === item.id && !locked;
          const pending =
            markCompletionMutation.isPending &&
            markCompletionMutation.variables?.itemId === item.id;

          return (
            <div
              className={[
                'checklist-item',
                `checklist-item--${item.status}`,
                open ? 'checklist-item--open' : undefined,
              ]
                .filter(Boolean)
                .join(' ')}
              key={item.id}
            >
              <button
                className="checklist-item__header"
                disabled={locked}
                onClick={() => setOpenItemId(open ? null : item.id)}
                type="button"
              >
                <span className="checklist-item__bullet">
                  {item.completed ? '✓' : item.number}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block font-semibold">{item.label}</span>
                  <span className="block text-sm text-slate-500">
                    {item.hint}
                  </span>
                </span>
                <ChecklistMeta issueCount={issueCount} item={item} />
                {!locked ? (
                  <span
                    aria-hidden="true"
                    className={[
                      'text-xl leading-none text-slate-500 transition',
                      open ? 'rotate-90' : undefined,
                    ]
                      .filter(Boolean)
                      .join(' ')}
                  >
                    ›
                  </span>
                ) : null}
              </button>

              {open ? (
                <div className="checklist-item__content">
                  <ChecklistItemContent
                    fiscalMutationPending={fiscalMutation.isPending}
                    issueCount={issueCount}
                    item={item}
                    markDonePending={pending}
                    onConfirmFiscalYear={(fiscalYear) =>
                      fiscalMutation.mutate(fiscalYear)
                    }
                    onMarkDone={() => handleMarkDone(item.id)}
                    setup={setup}
                  />
                </div>
              ) : null}
            </div>
          );
        })}
      </div>
    </section>
  );
}

function ChecklistItemContent({
  fiscalMutationPending,
  issueCount,
  item,
  markDonePending,
  onConfirmFiscalYear,
  onMarkDone,
  setup,
}: {
  fiscalMutationPending: boolean;
  issueCount: number | null;
  item: ProjectChecklistItem;
  markDonePending: boolean;
  onConfirmFiscalYear: (fiscalYear: string) => void;
  onMarkDone: () => void;
  setup: ProjectIdentificationSetupResponse;
}) {
  if (item.kind === 'select') {
    return (
      <FiscalPeriodChecklistContent
        item={item}
        key={setup.fiscalYear}
        onConfirmFiscalYear={onConfirmFiscalYear}
        pending={fiscalMutationPending}
        setup={setup}
      />
    );
  }

  if (item.kind === 'upload') {
    return (
      <FlatFileImportChecklistItem
        completed={item.completed}
        dataset={item.id as ImportDatasetId}
        latestImport={item.latestImport}
        markDonePending={markDonePending}
        onMarkDone={onMarkDone}
        ready={item.ready}
        stale={item.stale}
        staleReason={item.staleReason}
      />
    );
  }

  if (item.kind === 'import') {
    return (
      <PgmImportChecklistContent
        item={item}
        markDonePending={markDonePending}
        onMarkDone={onMarkDone}
        setup={setup}
      />
    );
  }

  if (item.kind === 'review') {
    const issuesResolved = issueCount === 0;

    return (
      <div className="space-y-3">
        <p className="text-sm text-slate-600">
          {issueCount === null
            ? 'Project issues are still being checked. Review can be marked complete after the project list loads.'
            : issueCount > 0
              ? `${issueCount.toLocaleString()} ${
                  issueCount === 1 ? 'project needs' : 'projects need'
                } review in the table below. Each issue must be resolved or explicitly accepted before finalizing.`
              : 'No project issues were detected. You can mark this checklist item reviewed.'}
        </p>
        <button
          className="btn btn-primary"
          disabled={!issuesResolved || item.completed || markDonePending}
          onClick={onMarkDone}
          type="button"
        >
          {markDonePending
            ? 'Saving'
            : item.completed
              ? 'Reviewed'
              : 'Mark all reviewed'}
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <p className="text-sm text-slate-600">
        Finalizing will be enabled when project issue acceptance and expense
        pull behavior are implemented.
      </p>
      <button className="btn btn-primary" disabled type="button">
        Finalize projects
      </button>
    </div>
  );
}

function FiscalPeriodChecklistContent({
  item,
  onConfirmFiscalYear,
  pending,
  setup,
}: {
  item: ProjectChecklistItem;
  onConfirmFiscalYear: (fiscalYear: string) => void;
  pending: boolean;
  setup: ProjectIdentificationSetupResponse;
}) {
  const [selectedFiscalYear, setSelectedFiscalYear] = useState(
    setup.fiscalYear
  );
  const selectedOption =
    setup.fiscalPeriodOptions.find(
      (option) => option.fiscalYear === selectedFiscalYear
    ) ?? setup.fiscalPeriodOptions[0];

  return (
    <div className="space-y-4">
      <div className="grid gap-3 lg:grid-cols-2">
        <label className="form-control w-full">
          <span className="label-text">Fiscal year</span>
          <select
            className="select select-bordered w-full"
            onChange={(event) => setSelectedFiscalYear(event.target.value)}
            value={selectedFiscalYear}
          >
            {setup.fiscalPeriodOptions.map((option) => (
              <option key={option.fiscalYear} value={option.fiscalYear}>
                {option.fiscalYear.replace('FY', 'FY:')}
              </option>
            ))}
          </select>
        </label>

        <label className="form-control w-full">
          <span className="label-text">Period</span>
          <select
            className="select select-bordered w-full"
            disabled
            value={selectedOption?.label ?? ''}
          >
            <option>{selectedOption?.label ?? ''}</option>
          </select>
        </label>
      </div>

      <div className="flex justify-end">
        <button
          className="btn btn-primary"
          disabled={pending}
          onClick={() => onConfirmFiscalYear(selectedFiscalYear)}
          type="button"
        >
          {pending ? 'Saving' : item.completed ? 'Change' : 'Confirm'}
        </button>
      </div>
    </div>
  );
}

function PgmImportChecklistContent({
  item,
  markDonePending,
  onMarkDone,
  setup,
}: {
  item: ProjectChecklistItem;
  markDonePending: boolean;
  onMarkDone: () => void;
  setup: ProjectIdentificationSetupResponse;
}) {
  const queryClient = useQueryClient();
  const [result, setResult] = useState<PgmImportResponse | null>(null);
  const mutation = useMutation({
    mutationFn: () =>
      fetchJson<PgmImportResponse>(
        `/api/pgmprojects/import?reportDate=${encodeURIComponent(
          setup.cycleEnd
        )}`,
        {
          method: 'POST',
        }
      ),
    onSuccess: (response) => {
      setResult(response);
      void queryClient.invalidateQueries({
        queryKey: ['projectIdentification', 'setup'],
      });
      void queryClient.invalidateQueries({ queryKey: ['projectList'] });
    },
  });
  const rows = result?.rowsImported ?? item.source?.rows ?? null;
  const importedAt = item.source?.completedAt;
  const canMarkDone = item.ready && !item.completed && !markDonePending;

  return (
    <div className="space-y-4">
      {rows ? (
        <div className="rounded border border-slate-200 bg-slate-50 p-3 text-sm">
          <div className="font-semibold">PGM Master Data</div>
          <div className="mt-1 text-slate-600">
            {rows.toLocaleString()} rows imported
            {importedAt ? ` on ${formatDate(importedAt)}` : ''}.
          </div>
        </div>
      ) : (
        <p className="text-sm text-slate-600">
          Pulls AE Redshift PGM master data for the selected reporting cycle.
        </p>
      )}

      {mutation.isError ? (
        <div className="alert alert-error py-3 text-sm">
          <span>PGM master data could not be imported.</span>
        </div>
      ) : null}

      <p className="text-sm font-medium text-amber-700">
        This import may take several minutes. Do not reload your browser while it
        runs.
      </p>

      <div className="flex flex-wrap justify-end gap-2">
        <button
          className="btn btn-outline"
          disabled={mutation.isPending}
          onClick={() => mutation.mutate()}
          type="button"
        >
          {mutation.isPending
            ? 'Importing'
            : item.ready
              ? 'Re-import'
              : 'Run import'}
        </button>
        <button
          className="btn btn-primary"
          disabled={!canMarkDone}
          onClick={onMarkDone}
          type="button"
        >
          {markDonePending
            ? 'Saving'
            : item.completed
              ? 'Done'
              : item.ready
                ? 'Mark done'
                : 'Awaiting import'}
        </button>
      </div>
    </div>
  );
}

function ChecklistMeta({
  issueCount,
  item,
}: {
  issueCount: number | null;
  item: ProjectChecklistItem;
}) {
  if (item.kind === 'review') {
    if (issueCount === null) {
      return <span className="badge badge-neutral">Checking</span>;
    }

    return (
      <span
        className={
          issueCount > 0 ? 'badge badge-warning' : 'badge badge-success'
        }
      >
        {issueCount > 0 ? `${issueCount.toLocaleString()} issues` : 'No issues'}
      </span>
    );
  }

  if (item.kind === 'upload' && item.latestImport) {
    const className =
      item.latestImport.status === 'Succeeded'
        ? 'badge badge-success'
        : 'badge badge-error';
    const rowCount =
      item.latestImport.status === 'Succeeded'
        ? item.latestImport.rowsImported
        : item.latestImport.attemptedRows;

    return (
      <span className={className}>{rowCount?.toLocaleString() ?? 0} rows</span>
    );
  }

  if (item.kind === 'import' && item.source?.rows) {
    return (
      <span className="badge badge-neutral">
        {item.source.rows.toLocaleString()} rows
      </span>
    );
  }

  if (item.status === 'ready') {
    return <span className="badge badge-info">Ready</span>;
  }

  if (item.status === 'stale') {
    return <span className="badge badge-warning">Needs review</span>;
  }

  return null;
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

function findFirstIncompleteItemId(
  setup: ProjectIdentificationSetupResponse
): string | null {
  return setup.checklistItems.find((item) => !item.completed)?.id ?? null;
}
