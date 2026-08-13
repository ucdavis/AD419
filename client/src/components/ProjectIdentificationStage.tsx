import {
  useCallback,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { DataTable } from '@/shared/dataTable.tsx';
import { HttpError } from '@/lib/api.ts';
import {
  allProjectCandidatesQueryOptions,
  excludeProject,
  includeProject,
  linkAllProject,
  linkPgmAward,
  pgmAwardCandidatesQueryOptions,
  projectListQueryOptions,
  setProjectSfn,
  sfnCandidatesQueryOptions,
  type AllProjectCandidate,
  type PgmAwardCandidate,
  type ProjectListRow,
  type ProjectListResponse,
  type ProjectListStatus,
  type ProjectListSummary,
  type SfnCandidate,
} from '@/queries/projectList.ts';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';
import {
  projectIdentificationSetupQueryOptions,
  type ProjectIdentificationSetupResponse,
} from '@/queries/projectIdentification.ts';
import { ProjectIdentificationSetupChecklist } from '@/components/ProjectIdentificationSetupChecklist.tsx';

type ProjectListTab = 'issues' | 'clean' | 'all' | 'excluded';

const tabs: { id: ProjectListTab; label: string }[] = [
  { id: 'issues', label: 'Issues' },
  { id: 'clean', label: 'Clean' },
  { id: 'all', label: 'All' },
  { id: 'excluded', label: 'Excluded' },
];

function displayValue(value: string | null): string {
  return value && value.trim() ? value : '-';
}

function statusClassName(status: ProjectListStatus): string {
  if (status === 'Clean') {
    return 'badge badge-success badge-outline whitespace-nowrap';
  }

  if (status === 'Excluded') {
    return 'badge badge-neutral badge-outline whitespace-nowrap';
  }

  if (status === 'SFN mismatch') {
    return 'badge badge-warning whitespace-nowrap';
  }

  return 'badge badge-error badge-outline whitespace-nowrap';
}

function rowsForTab(rows: ProjectListRow[], tab: ProjectListTab) {
  if (tab === 'issues') {
    return rows.filter((row) => row.status !== 'Clean');
  }

  if (tab === 'clean') {
    return rows.filter((row) => row.status === 'Clean');
  }

  return rows;
}

function projectListHeading(counts: ProjectListResponse['counts']) {
  if (counts.excluded > 0) {
    return `Project list · ${counts.all} active (${counts.excluded} excluded from associations)`;
  }

  return `Project list · ${counts.all}`;
}

function sfnDistributionText(summary: ProjectListSummary): string {
  if (summary.sfnDistribution.length === 0) {
    return '-';
  }

  return summary.sfnDistribution
    .map((item) => `${item.sfn}: ${item.count}`)
    .join(' / ');
}

export function ProjectIdentificationStage() {
  const setupQuery = useQuery(projectIdentificationSetupQueryOptions());

  if (setupQuery.isLoading) {
    return <p>Loading project identification setup...</p>;
  }

  if (setupQuery.isError || !setupQuery.data) {
    return (
      <div className="alert alert-error items-start" role="alert">
        <div>
          <h2 className="font-bold">Unable to load project setup</h2>
          <p>The project identification checklist could not be loaded.</p>
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

  return <ProjectIdentificationStageContent setup={setupQuery.data} />;
}

function ProjectIdentificationStageContent({
  setup,
}: {
  setup: ProjectIdentificationSetupResponse;
}) {
  const pgmItem = setup.checklistItems.find(
    (item) => item.id === 'pgm-master-data'
  );
  const projectListReady = pgmItem?.completed ?? false;
  const { data, error, isError, isFetching, isLoading, refetch } = useQuery({
    ...projectListQueryOptions(setup.fiscalYear),
    enabled: projectListReady,
  });
  const [activeTab, setActiveTab] = useState<ProjectListTab>('issues');

  const columns = useMemo<ColumnDef<ProjectListRow>[]>(
    () => [
      {
        accessorFn: (row) => row.nifaProject ?? '',
        cell: ({ row }) => displayValue(row.original.nifaProject),
        header: 'NIFA Project',
        id: 'nifaProject',
      },
      {
        accessorFn: (row) => row.accession ?? '',
        cell: ({ row }) => displayValue(row.original.accession),
        header: 'Accession',
        id: 'accession',
      },
      {
        accessorFn: (row) => row.awardNumber ?? '',
        cell: ({ row }) => displayValue(row.original.awardNumber),
        header: 'Award #',
        id: 'awardNumber',
      },
      {
        accessorFn: (row) => row.ae ?? '',
        cell: ({ row }) => (
          <div className="project-list-ae-cell">
            {displayValue(row.original.ae)}
          </div>
        ),
        header: 'AE',
        id: 'ae',
        meta: {
          cellClassName: 'project-list-ae-column',
        },
      },
      {
        accessorFn: (row) => (row.is204 ? 'Yes' : 'No'),
        cell: ({ row }) => (row.original.is204 ? 'Yes' : 'No'),
        header: '204',
        id: 'is204',
      },
      {
        accessorFn: (row) => row.pi ?? '',
        cell: ({ row }) => displayValue(row.original.pi),
        header: 'PI',
        id: 'pi',
      },
      {
        accessorFn: (row) => row.pdEmailAddress ?? '',
        cell: ({ row }) => displayValue(row.original.pdEmailAddress),
        header: 'PD Email',
        id: 'pdEmailAddress',
      },
      {
        accessorFn: (row) => row.ucpEmployeeId ?? '',
        cell: ({ row }) => displayValue(row.original.ucpEmployeeId),
        header: 'UCP Employee ID',
        id: 'ucpEmployeeId',
        meta: {
          cellClassName: 'whitespace-nowrap',
          headerClassName: 'whitespace-nowrap',
        },
      },
      {
        accessorFn: (row) => row.ucPathName ?? '',
        cell: ({ row }) => displayValue(row.original.ucPathName),
        header: 'UCPath Name',
        id: 'ucPathName',
        meta: {
          headerClassName: 'whitespace-nowrap',
        },
      },
      {
        accessorFn: (row) => row.department ?? '',
        cell: ({ row }) => displayValue(row.original.department),
        header: 'Department',
        id: 'department',
      },
      {
        accessorFn: (row) => row.sfn ?? '',
        cell: ({ row }) => displayValue(row.original.sfn),
        header: 'SFN',
        id: 'sfn',
      },
      {
        accessorFn: (row) => row.status,
        cell: ({ row }) => (
          <span className={statusClassName(row.original.status)}>
            {row.original.status}
          </span>
        ),
        header: 'Status',
        id: 'status',
        meta: {
          cellClassName: 'whitespace-nowrap',
          headerClassName: 'whitespace-nowrap',
        },
      },
      {
        accessorFn: (row) => row.notes ?? '',
        cell: ({ row }) => displayValue(row.original.notes),
        header: 'Notes',
        id: 'notes',
      },
      {
        cell: ({ row }) => (
          <ProjectIssueResolutionControl
            fiscalYear={setup.fiscalYear}
            row={row.original}
          />
        ),
        enableSorting: false,
        header: 'Actions',
        id: 'actions',
        meta: {
          cellClassName: 'min-w-56 align-top',
          headerClassName: 'whitespace-nowrap',
        },
      },
    ],
    [setup.fiscalYear]
  );

  const issueCount = data?.summary.issuesToResolve ?? null;

  if (isError) {
    const message =
      error instanceof Error
        ? error.message
        : 'The project list could not be loaded.';

    return (
      <div className="workflow-stack">
        <ProjectIdentificationSetupChecklist
          issueCount={issueCount}
          setup={setup}
        />
        <div className="alert alert-error items-start" role="alert">
          <div>
            <h2 className="font-bold">Unable to load project list</h2>
            <p>{message}</p>
            <button
              className="btn btn-sm mt-3"
              disabled={isFetching}
              onClick={() => void refetch()}
              type="button"
            >
              {isFetching ? 'Retrying...' : 'Retry'}
            </button>
          </div>
        </div>
      </div>
    );
  }

  const visibleRows = data
    ? activeTab === 'excluded'
      ? data.excludedRows
      : rowsForTab(data.rows, activeTab)
    : [];

  return (
    <div className="workflow-stack">
      {data ? <ProjectSummaryCards summary={data.summary} /> : null}

      <ProjectIdentificationSetupChecklist
        issueCount={issueCount}
        setup={setup}
      />

      <div className="rounded border border-slate-200 bg-white shadow-sm">
        <div className="flex flex-col gap-3 border-b border-slate-200 px-4 py-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-normal text-slate-500">
              Reference &amp; Issue Resolution
            </p>
            <h2 className="text-lg font-bold tracking-normal text-slate-950">
              {data ? projectListHeading(data.counts) : 'Project list'}
            </h2>
          </div>
        </div>

        <div className="space-y-4 p-4">
          {isLoading ? (
            <p>Loading project list...</p>
          ) : !projectListReady ? (
            <div className="rounded border border-dashed border-slate-300 bg-slate-50 p-8 text-center text-slate-600">
              Project list will appear after PGM master data is imported and
              marked done.
            </div>
          ) : data ? (
            <>
              <div className="tabs tabs-bordered" role="tablist">
                {tabs.map((tab) => {
                  const count = data.counts[tab.id];

                  return (
                    <button
                      aria-selected={activeTab === tab.id}
                      className={`tab ${
                        activeTab === tab.id ? 'tab-active' : ''
                      }`}
                      key={tab.id}
                      onClick={() => setActiveTab(tab.id)}
                      role="tab"
                      type="button"
                    >
                      {tab.label}
                      <span className="badge badge-sm ml-2">{count}</span>
                    </button>
                  );
                })}
              </div>

              <DataTable
                cellClassName="align-top"
                columns={columns}
                data={visibleRows}
                filterPlaceholder="Search project, accession, person..."
                headerClassName="align-top"
                initialState={{ pagination: { pageSize: 25 } }}
                key={activeTab}
                tableClassName="project-list-table table-zebra table-sm"
              />
            </>
          ) : null}
        </div>
      </div>
    </div>
  );
}

type ResolutionMode = 'all-project' | 'pgm-award' | 'sfn';
type ExclusionDialogAction = 'exclude' | 'include';
type ResolutionAction =
  | { kind: 'exclude'; notes: string | null }
  | { kind: 'include'; notes: string | null }
  | { allProjectId: number; kind: 'link-all-project' }
  | { awardKey: string; kind: 'link-pgm-award' }
  | { kind: 'set-sfn'; sfn: string };

function ProjectIssueResolutionControl({
  fiscalYear,
  row,
}: {
  fiscalYear: string;
  row: ProjectListRow;
}) {
  const accession = row.accession;
  const queryClient = useQueryClient();
  const [mode, setMode] = useState<ResolutionMode | null>(null);
  const [search, setSearch] = useState('');
  const [exclusionDialogAction, setExclusionDialogAction] =
    useState<ExclusionDialogAction | null>(null);
  const controlRef = useRef<HTMLDivElement>(null);
  const closePicker = useCallback(() => {
    setMode(null);
    setSearch('');
  }, []);
  const invalidateProjectState = () => {
    void queryClient.invalidateQueries({ queryKey: ['projectList'] });
    void queryClient.invalidateQueries({
      queryKey: ['projectIdentification', 'setup'],
    });
  };
  const mutation = useMutation({
    mutationFn: (action: ResolutionAction) => {
      const projectAccession = requireAccession(accession);

      switch (action.kind) {
        case 'exclude':
          return excludeProject(fiscalYear, projectAccession, action.notes);
        case 'include':
          return includeProject(fiscalYear, projectAccession, action.notes);
        case 'link-all-project':
          return linkAllProject(
            fiscalYear,
            projectAccession,
            action.allProjectId
          );
        case 'link-pgm-award':
          return linkPgmAward(fiscalYear, projectAccession, action.awardKey);
        case 'set-sfn':
          return setProjectSfn(fiscalYear, projectAccession, action.sfn);
      }
    },
    onSuccess: () => {
      closePicker();
      setExclusionDialogAction(null);
      invalidateProjectState();
    },
  });

  useEffect(() => {
    if (mode === null || exclusionDialogAction !== null) {
      return;
    }

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closePicker();
      }
    };

    const handlePointerDown = (event: MouseEvent) => {
      const target = event.target as Node | null;

      if (target && !controlRef.current?.contains(target)) {
        closePicker();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    document.addEventListener('mousedown', handlePointerDown);

    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      document.removeEventListener('mousedown', handlePointerDown);
    };
  }, [closePicker, exclusionDialogAction, mode]);

  if (row.status === 'Clean' || !accession) {
    return <span className="text-sm text-slate-400">-</span>;
  }

  const pending = mutation.isPending;
  const activePicker =
    mode === 'all-project' ? (
      <AllProjectPicker
        accession={accession}
        disabled={pending}
        fiscalYear={fiscalYear}
        onCancel={closePicker}
        onSelect={(candidate) =>
          mutation.mutate({
            allProjectId: candidate.allProjectId,
            kind: 'link-all-project',
          })
        }
        search={search}
        setSearch={setSearch}
      />
    ) : mode === 'pgm-award' ? (
      <PgmAwardPicker
        accession={accession}
        disabled={pending}
        fiscalYear={fiscalYear}
        onCancel={closePicker}
        onSelect={(candidate) =>
          mutation.mutate({
            awardKey: candidate.awardKey,
            kind: 'link-pgm-award',
          })
        }
        search={search}
        setSearch={setSearch}
      />
    ) : mode === 'sfn' ? (
      <SfnPicker
        accession={accession}
        disabled={pending}
        fiscalYear={fiscalYear}
        onCancel={closePicker}
        onSelect={(candidate) =>
          mutation.mutate({ kind: 'set-sfn', sfn: candidate.sfn })
        }
      />
    ) : null;

  return (
    <div className="relative space-y-2" ref={controlRef}>
      <div className="flex flex-wrap justify-end gap-2">
        {row.status === 'Excluded' ? (
          <button
            className="btn btn-xs btn-outline"
            disabled={pending}
            onClick={() => setExclusionDialogAction('include')}
            type="button"
          >
            Re-include
          </button>
        ) : null}

        {row.status === 'No PGM match' ? (
          <button
            className="btn btn-xs btn-outline"
            disabled={pending}
            onClick={() => setMode(mode === 'pgm-award' ? null : 'pgm-award')}
            type="button"
          >
            Select PGM award
          </button>
        ) : null}

        {row.status === 'Not in All Projects' ? (
          <button
            className="btn btn-xs btn-outline"
            disabled={pending}
            onClick={() =>
              setMode(mode === 'all-project' ? null : 'all-project')
            }
            type="button"
          >
            Select All Projects
          </button>
        ) : null}

        {row.status === 'SFN mismatch' ? (
          <button
            className="btn btn-xs btn-outline"
            disabled={pending}
            onClick={() => setMode(mode === 'sfn' ? null : 'sfn')}
            type="button"
          >
            Select SFN
          </button>
        ) : null}

        {row.status === 'No PGM match' ||
        row.status === 'Not in All Projects' ? (
          <button
            className="btn btn-xs btn-ghost text-error"
            disabled={pending}
            onClick={() => setExclusionDialogAction('exclude')}
            type="button"
          >
            Exclude
          </button>
        ) : null}
      </div>

      {mutation.isError ? (
        <div className="alert alert-error py-2 text-xs" role="alert">
          {resolutionErrorMessage(mutation.error)}
        </div>
      ) : null}

      {activePicker ? (
        <div className="absolute right-0 top-full z-30 mt-2 w-96 max-w-[calc(100vw-2rem)] text-left">
          {activePicker}
        </div>
      ) : null}

      {exclusionDialogAction ? (
        <ProjectExclusionDialog
          action={exclusionDialogAction}
          disabled={pending}
          initialNotes={row.notes}
          key={exclusionDialogAction}
          onCancel={() => setExclusionDialogAction(null)}
          onConfirm={(notes) => {
            const action = exclusionDialogAction;
            setExclusionDialogAction(null);
            if (action === 'exclude') {
              mutation.mutate({ kind: 'exclude', notes });
              return;
            }

            mutation.mutate({ kind: 'include', notes });
          }}
        />
      ) : null}
    </div>
  );
}

function ProjectExclusionDialog({
  action,
  disabled,
  initialNotes,
  onCancel,
  onConfirm,
}: {
  action: ExclusionDialogAction;
  disabled: boolean;
  initialNotes: string | null;
  onCancel: () => void;
  onConfirm: (notes: string | null) => void;
}) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const noteId = useId();
  const [notes, setNotes] = useState(initialNotes ?? '');
  const title =
    action === 'include' ? 'Re-include project?' : 'Exclude project?';
  const confirmLabel =
    action === 'include' ? 'Re-include project' : 'Exclude project';
  const confirmClassName = action === 'include' ? 'btn-primary' : 'btn-error';
  const description =
    action === 'include'
      ? 'This project will return to the active project identification list for the current review.'
      : 'This project will be hidden from the project identification list for the current review.';

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) {
      return;
    }

    if (!dialog.open) {
      if (typeof dialog.showModal === 'function') {
        dialog.showModal();
      } else {
        dialog.setAttribute('open', '');
      }
    }
  }, []);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) {
      return;
    }

    const handleCancel = (event: Event) => {
      event.preventDefault();
      onCancel();
    };

    dialog.addEventListener('cancel', handleCancel);
    return () => dialog.removeEventListener('cancel', handleCancel);
  }, [onCancel]);

  return (
    <dialog aria-labelledby={titleId} className="modal" ref={dialogRef}>
      <div className="modal-box max-w-lg">
        <h2 className="text-lg font-bold text-base-content" id={titleId}>
          {title}
        </h2>
        <div className="mt-3 space-y-4 text-sm text-base-content/70">
          <p>{description}</p>
          <label className="form-control w-full" htmlFor={noteId}>
            <span className="label-text">Note</span>
            <textarea
              className="textarea textarea-bordered min-h-28 w-full"
              disabled={disabled}
              id={noteId}
              onChange={(event) => setNotes(event.target.value)}
              value={notes}
            />
          </label>
        </div>
        <div className="modal-action">
          <button
            className="btn btn-ghost"
            disabled={disabled}
            onClick={onCancel}
            type="button"
          >
            Cancel
          </button>
          <button
            className={`btn ${confirmClassName}`}
            disabled={disabled}
            onClick={() => onConfirm(notes)}
            type="button"
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </dialog>
  );
}

function AllProjectPicker({
  accession,
  disabled,
  fiscalYear,
  onCancel,
  onSelect,
  search,
  setSearch,
}: {
  accession: string;
  disabled: boolean;
  fiscalYear: string;
  onCancel: () => void;
  onSelect: (candidate: AllProjectCandidate) => void;
  search: string;
  setSearch: (value: string) => void;
}) {
  const debouncedSearch = useDebouncedValue(search);
  const query = useQuery({
    ...allProjectCandidatesQueryOptions(fiscalYear, accession, debouncedSearch),
    enabled: Boolean(accession),
  });
  const candidates = query.data ?? [];

  return (
    <CandidatePanel
      emptyText="No All Projects matches found."
      isEmpty={candidates.length === 0}
      isLoading={query.isLoading}
      onCancel={onCancel}
      search={search}
      setSearch={setSearch}
    >
      {candidates.map((candidate) => (
        <button
          className="w-full rounded border border-slate-200 p-2 text-left text-xs hover:bg-slate-50"
          disabled={disabled}
          key={candidate.allProjectId}
          onClick={() => onSelect(candidate)}
          type="button"
        >
          <span className="block font-semibold">
            {displayValue(candidate.projectNumber)} ·{' '}
            {displayValue(candidate.awardNumber)}
          </span>
          <span className="block text-slate-600">
            {displayValue(candidate.title)}
          </span>
          <span className="block text-slate-500">
            {displayValue(candidate.projectDirector)} ·{' '}
            {displayValue(candidate.department)}
          </span>
        </button>
      ))}
    </CandidatePanel>
  );
}

function PgmAwardPicker({
  accession,
  disabled,
  fiscalYear,
  onCancel,
  onSelect,
  search,
  setSearch,
}: {
  accession: string;
  disabled: boolean;
  fiscalYear: string;
  onCancel: () => void;
  onSelect: (candidate: PgmAwardCandidate) => void;
  search: string;
  setSearch: (value: string) => void;
}) {
  const debouncedSearch = useDebouncedValue(search);
  const query = useQuery({
    ...pgmAwardCandidatesQueryOptions(fiscalYear, accession, debouncedSearch),
    enabled: Boolean(accession),
  });
  const candidates = query.data ?? [];

  return (
    <CandidatePanel
      emptyText="No PGM awards found."
      isEmpty={candidates.length === 0}
      isLoading={query.isLoading}
      onCancel={onCancel}
      search={search}
      setSearch={setSearch}
    >
      {candidates.map((candidate) => (
        <button
          className="w-full rounded border border-slate-200 p-2 text-left text-xs hover:bg-slate-50"
          disabled={disabled}
          key={candidate.awardKey}
          onClick={() => onSelect(candidate)}
          type="button"
        >
          <span className="block font-semibold">
            {displayValue(candidate.sponsorAwardNumber)} ·{' '}
            {displayValue(candidate.projectNumbers)}
          </span>
          <span className="block text-slate-600">
            {displayValue(candidate.awardName)}
          </span>
          <span className="block text-slate-500">
            {displayValue(candidate.principalInvestigatorNames)} ·{' '}
            {displayValue(candidate.pgmSfnBucket)}
          </span>
        </button>
      ))}
    </CandidatePanel>
  );
}

function SfnPicker({
  accession,
  disabled,
  fiscalYear,
  onCancel,
  onSelect,
}: {
  accession: string;
  disabled: boolean;
  fiscalYear: string;
  onCancel: () => void;
  onSelect: (candidate: SfnCandidate) => void;
}) {
  const query = useQuery({
    ...sfnCandidatesQueryOptions(fiscalYear, accession),
    enabled: Boolean(accession),
  });

  if (query.isLoading) {
    return (
      <div className="ml-auto w-80 max-w-full space-y-2 rounded border border-slate-200 bg-white p-2 text-left text-xs text-slate-500 shadow-sm">
        Loading SFNs...
        <div className="flex justify-end">
          <button
            className="btn btn-ghost btn-xs"
            onClick={onCancel}
            type="button"
          >
            Cancel
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="ml-auto w-80 max-w-full rounded border border-slate-200 bg-white p-1 text-left shadow-sm">
      {(query.data ?? []).length === 0 ? (
        <p className="px-2 py-1 text-xs text-slate-500">
          No SFN candidates found.
        </p>
      ) : (
        <div className="space-y-1">
          {(query.data ?? []).map((candidate) => (
            <button
              aria-label={`${candidate.sfn} - ${candidate.description}${
                candidate.source ? ` · ${candidate.source}` : ''
              }`}
              className={[
                'flex w-full items-start gap-2 rounded px-2 py-1.5 text-left text-xs transition',
                'disabled:cursor-not-allowed disabled:opacity-60',
                candidate.isRecommended
                  ? 'bg-sky-50 text-slate-950 hover:bg-sky-100'
                  : 'text-slate-700 hover:bg-slate-100',
              ].join(' ')}
              disabled={disabled}
              key={`${candidate.source}-${candidate.sfn}`}
              onClick={() => onSelect(candidate)}
              type="button"
            >
              <span
                className={[
                  'shrink-0 rounded border px-1.5 py-0.5 font-semibold leading-none',
                  candidate.isRecommended
                    ? 'border-sky-700 bg-sky-700 text-white'
                    : 'border-slate-300 bg-slate-50 text-slate-700',
                ].join(' ')}
              >
                {candidate.sfn}
              </span>
              <span className="min-w-0">
                <span className="block break-words font-medium leading-snug">
                  {candidate.description}
                </span>
                {candidate.source ? (
                  <span className="mt-0.5 block break-words text-[0.68rem] leading-snug text-slate-500">
                    {candidate.source}
                  </span>
                ) : null}
              </span>
            </button>
          ))}
        </div>
      )}
      <div className="mt-1 flex justify-end border-t border-slate-100 pt-1">
        <button
          className="btn btn-ghost btn-xs"
          onClick={onCancel}
          type="button"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}

function CandidatePanel({
  children,
  emptyText,
  isEmpty,
  isLoading,
  onCancel,
  search,
  setSearch,
}: {
  children: ReactNode;
  emptyText: string;
  isEmpty: boolean;
  isLoading: boolean;
  onCancel: () => void;
  search: string;
  setSearch: (value: string) => void;
}) {
  return (
    <div className="space-y-2 rounded border border-slate-200 bg-white p-2 shadow-sm">
      <input
        aria-label="Search candidates"
        className="input input-bordered input-xs w-full"
        onChange={(event) => setSearch(event.target.value)}
        placeholder="Search candidates"
        type="search"
        value={search}
      />
      {isLoading ? (
        <p className="text-xs text-slate-500">Loading candidates...</p>
      ) : isEmpty ? (
        <p className="text-xs text-slate-500">{emptyText}</p>
      ) : (
        <div className="max-h-60 space-y-1 overflow-y-auto">{children}</div>
      )}
      <div className="flex justify-end border-t border-slate-100 pt-2">
        <button
          className="btn btn-ghost btn-xs"
          onClick={onCancel}
          type="button"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}

function requireAccession(accession: string | null) {
  if (!accession) {
    throw new Error('Accession number is required.');
  }

  return accession;
}

function resolutionErrorMessage(error: unknown) {
  if (error instanceof HttpError) {
    if (typeof error.body === 'string' && error.body.trim()) {
      return error.body;
    }

    if (
      error.body &&
      typeof error.body === 'object' &&
      'message' in error.body &&
      typeof error.body.message === 'string' &&
      error.body.message.trim()
    ) {
      return error.body.message;
    }
  }

  return 'Resolution could not be saved.';
}

function useDebouncedValue(value: string, delayMs = 250) {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => {
      setDebouncedValue(value);
    }, delayMs);

    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debouncedValue;
}

function ProjectSummaryCards({ summary }: { summary: ProjectListSummary }) {
  const summaryCards = [
    ['Active NIFA', summary.activeNifa],
    ['All NIFA', summary.allNifa],
    ['PGM records', summary.pgmRecords],
    ['ALN codes', summary.alnCodes],
    ['Excluded NIFA', summary.excludedNifa],
    ['Issues to resolve', summary.issuesToResolve],
    ['SFN distribution', sfnDistributionText(summary)],
  ];

  return (
    <section className="rounded border border-slate-200 bg-white p-4 shadow-sm">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-7">
        {summaryCards.map(([label, value]) => (
          <div
            className="rounded border border-slate-200 bg-slate-50 p-3"
            key={label}
          >
            <div className="text-xs font-semibold uppercase text-slate-500">
              {label}
            </div>
            <div className="mt-1 text-lg font-bold text-slate-950">{value}</div>
          </div>
        ))}
      </div>
    </section>
  );
}
