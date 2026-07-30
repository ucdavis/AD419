import { useMemo, useState } from 'react';
import { DataTable } from '@/shared/dataTable.tsx';
import {
  projectListQueryOptions,
  type ProjectListRow,
  type ProjectListStatus,
  type ProjectListSummary,
} from '@/queries/projectList.ts';
import { useQuery } from '@tanstack/react-query';
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
  const { data, error, isError, isFetching, isLoading, refetch } = useQuery(
    projectListQueryOptions(setup.fiscalYear)
  );
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
        accessorFn: (row) => row.pi ?? '',
        cell: ({ row }) => displayValue(row.original.pi),
        header: 'PI',
        id: 'pi',
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
    ],
    []
  );

  const pgmItem = setup.checklistItems.find(
    (item) => item.id === 'pgm-master-data'
  );
  const projectListReady = pgmItem?.completed ?? false;
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
