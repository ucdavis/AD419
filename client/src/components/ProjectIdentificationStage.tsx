import { useMemo, useState, type ReactNode } from 'react';
import { DataTable } from '@/shared/dataTable.tsx';
import {
  allProjectCandidatesQueryOptions,
  excludeProject,
  linkAllProject,
  linkPgmAward,
  pgmAwardCandidatesQueryOptions,
  projectListQueryOptions,
  setProjectSfn,
  sfnCandidatesQueryOptions,
  type AllProjectCandidate,
  type PgmAwardCandidate,
  type ProjectListRow,
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

type ProjectListTab = 'issues' | 'clean' | 'all';

const tabs: { id: ProjectListTab; label: string }[] = [
  { id: 'issues', label: 'Issues' },
  { id: 'clean', label: 'Clean' },
  { id: 'all', label: 'All' },
];

function displayValue(value: string | null): string {
  return value && value.trim() ? value : '-';
}

function statusClassName(status: ProjectListStatus): string {
  if (status === 'Clean') {
    return 'badge badge-success badge-outline';
  }

  if (status === 'SFN mismatch') {
    return 'badge badge-warning';
  }

  return 'badge badge-error badge-outline';
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
        cell: ({ row }) => displayValue(row.original.ae),
        header: 'AE',
        id: 'ae',
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

  const visibleRows = data ? rowsForTab(data.rows, activeTab) : [];

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
              Project list{data ? ` · ${data.counts.all}` : ''}
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
                columns={columns}
                data={visibleRows}
                filterPlaceholder="Search project, accession, person..."
                initialState={{ pagination: { pageSize: 25 } }}
                key={activeTab}
                tableClassName="table-zebra table-sm"
              />
            </>
          ) : null}
        </div>
      </div>
    </div>
  );
}

type ResolutionMode = 'all-project' | 'pgm-award' | 'sfn';

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
  const invalidateProjectState = () => {
    void queryClient.invalidateQueries({ queryKey: ['projectList'] });
    void queryClient.invalidateQueries({
      queryKey: ['projectIdentification', 'setup'],
    });
  };
  const mutation = useMutation({
    mutationFn: async (action: () => Promise<void>) => action(),
    onSuccess: () => {
      setMode(null);
      setSearch('');
      invalidateProjectState();
    },
  });

  if (row.status === 'Clean' || !accession) {
    return <span className="text-sm text-slate-400">-</span>;
  }

  const pending = mutation.isPending;

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap gap-2">
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
            onClick={() =>
              mutation.mutate(() => excludeProject(fiscalYear, accession))
            }
            type="button"
          >
            Exclude
          </button>
        ) : null}
      </div>

      {mutation.isError ? (
        <div className="alert alert-error py-2 text-xs" role="alert">
          Resolution could not be saved.
        </div>
      ) : null}

      {mode === 'all-project' ? (
        <AllProjectPicker
          accession={accession}
          disabled={pending}
          fiscalYear={fiscalYear}
          onSelect={(candidate) =>
            mutation.mutate(() =>
              linkAllProject(fiscalYear, accession, candidate.allProjectId)
            )
          }
          search={search}
          setSearch={setSearch}
        />
      ) : null}

      {mode === 'pgm-award' ? (
        <PgmAwardPicker
          accession={accession}
          disabled={pending}
          fiscalYear={fiscalYear}
          onSelect={(candidate) =>
            mutation.mutate(() =>
              linkPgmAward(fiscalYear, accession, candidate.awardKey)
            )
          }
          search={search}
          setSearch={setSearch}
        />
      ) : null}

      {mode === 'sfn' ? (
        <SfnPicker
          accession={accession}
          disabled={pending}
          fiscalYear={fiscalYear}
          onSelect={(candidate) =>
            mutation.mutate(() =>
              setProjectSfn(fiscalYear, accession, candidate.sfn)
            )
          }
        />
      ) : null}
    </div>
  );
}

function AllProjectPicker({
  accession,
  disabled,
  fiscalYear,
  onSelect,
  search,
  setSearch,
}: {
  accession: string;
  disabled: boolean;
  fiscalYear: string;
  onSelect: (candidate: AllProjectCandidate) => void;
  search: string;
  setSearch: (value: string) => void;
}) {
  const query = useQuery({
    ...allProjectCandidatesQueryOptions(fiscalYear, accession, search),
    enabled: Boolean(accession),
  });

  return (
    <CandidatePanel
      emptyText="No All Projects matches found."
      isLoading={query.isLoading}
      search={search}
      setSearch={setSearch}
    >
      {(query.data ?? []).map((candidate) => (
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
  onSelect,
  search,
  setSearch,
}: {
  accession: string;
  disabled: boolean;
  fiscalYear: string;
  onSelect: (candidate: PgmAwardCandidate) => void;
  search: string;
  setSearch: (value: string) => void;
}) {
  const query = useQuery({
    ...pgmAwardCandidatesQueryOptions(fiscalYear, accession, search),
    enabled: Boolean(accession),
  });

  return (
    <CandidatePanel
      emptyText="No PGM awards found."
      isLoading={query.isLoading}
      search={search}
      setSearch={setSearch}
    >
      {(query.data ?? []).map((candidate) => (
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
  onSelect,
}: {
  accession: string;
  disabled: boolean;
  fiscalYear: string;
  onSelect: (candidate: SfnCandidate) => void;
}) {
  const query = useQuery({
    ...sfnCandidatesQueryOptions(fiscalYear, accession),
    enabled: Boolean(accession),
  });

  if (query.isLoading) {
    return <div className="text-xs text-slate-500">Loading SFNs...</div>;
  }

  return (
    <div className="space-y-1 rounded border border-slate-200 bg-white p-2">
      {(query.data ?? []).length === 0 ? (
        <p className="text-xs text-slate-500">No SFN candidates found.</p>
      ) : (
        (query.data ?? []).map((candidate) => (
          <button
            className="btn btn-xs btn-outline mr-1"
            disabled={disabled}
            key={`${candidate.source}-${candidate.sfn}`}
            onClick={() => onSelect(candidate)}
            type="button"
          >
            {candidate.sfn} · {candidate.source}
          </button>
        ))
      )}
    </div>
  );
}

function CandidatePanel({
  children,
  emptyText,
  isLoading,
  search,
  setSearch,
}: {
  children: ReactNode;
  emptyText: string;
  isLoading: boolean;
  search: string;
  setSearch: (value: string) => void;
}) {
  const items = Array.isArray(children) ? children.filter(Boolean) : children;
  const isEmpty = Array.isArray(items) && items.length === 0;

  return (
    <div className="space-y-2 rounded border border-slate-200 bg-white p-2">
      <input
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
        <div className="max-h-60 space-y-1 overflow-y-auto">{items}</div>
      )}
    </div>
  );
}

function ProjectSummaryCards({ summary }: { summary: ProjectListSummary }) {
  const summaryCards = [
    ['Active NIFA', summary.activeNifa],
    ['All NIFA', summary.allNifa],
    ['PGM records', summary.pgmRecords],
    ['ALN codes', summary.alnCodes],
    ['Issues to resolve', summary.issuesToResolve],
    ['SFN distribution', sfnDistributionText(summary)],
  ];

  return (
    <section className="rounded border border-slate-200 bg-white p-4 shadow-sm">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
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
