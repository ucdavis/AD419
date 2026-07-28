import { useMemo, useState } from 'react';
import { DataTable } from '@/shared/dataTable.tsx';
import {
  currentFiscalYear,
  projectListQueryOptions,
  type ProjectListRow,
  type ProjectListStatus,
  type ProjectListSummary,
} from '@/queries/projectList.ts';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

type ProjectListTab = 'issues' | 'clean' | 'all';

const tabs: { id: ProjectListTab; label: string }[] = [
  { id: 'issues', label: 'Issues' },
  { id: 'clean', label: 'Clean' },
  { id: 'all', label: 'All' },
];

function displayValue(value: string | null): string {
  return value && value.trim() ? value : '-';
}

function displayStatus(status: ProjectListStatus): string {
  return status === '204 outside college' ? '204 outside CAES' : status;
}

function statusClassName(status: ProjectListStatus): string {
  if (status === 'Clean') {
    return 'badge badge-success badge-outline';
  }

  if (status === '204 outside college' || status === 'SFN mismatch') {
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
  const fiscalYear = currentFiscalYear();
  const { data, error, isError, isFetching, isLoading, refetch } = useQuery(
    projectListQueryOptions(fiscalYear)
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
        accessorFn: (row) => row.orgr ?? '',
        cell: ({ row }) => displayValue(row.original.orgr),
        header: 'ORGR',
        id: 'orgr',
      },
      {
        accessorFn: (row) => row.sfn ?? '',
        cell: ({ row }) => displayValue(row.original.sfn),
        header: 'SFN',
        id: 'sfn',
      },
      {
        accessorFn: (row) => displayStatus(row.status),
        cell: ({ row }) => (
          <span className={statusClassName(row.original.status)}>
            {displayStatus(row.original.status)}
          </span>
        ),
        header: 'Status',
        id: 'status',
      },
    ],
    []
  );

  if (isLoading) {
    return <p>Loading project list...</p>;
  }

  if (isError) {
    const message =
      error instanceof Error
        ? error.message
        : 'The project list could not be loaded.';

    return (
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
    );
  }

  if (!data) {
    return <p>Loading project list...</p>;
  }

  const visibleRows = rowsForTab(data.rows, activeTab);
  const summaryCards = [
    ['Active NIFA', data.summary.activeNifa],
    ['All NIFA', data.summary.allNifa],
    ['PGM records', data.summary.pgmRecords],
    ['ALN codes', data.summary.alnCodes],
    ['Issues to resolve', data.summary.issuesToResolve],
    ['SFN distribution', sfnDistributionText(data.summary)],
  ];

  return (
    <div className="rounded border border-slate-200 bg-white shadow-sm">
      <div className="flex flex-col gap-3 border-b border-slate-200 px-4 py-4 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <p className="text-xs font-semibold uppercase tracking-normal text-slate-500">
            Reference &amp; Issue Resolution
          </p>
          <h2 className="text-lg font-bold tracking-normal text-slate-950">
            Project list · {data.counts.all}
          </h2>
        </div>
        <button className="btn btn-primary" disabled type="button">
          Finalize
        </button>
      </div>

      <div className="space-y-4 p-4">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
          {summaryCards.map(([label, value]) => (
            <div
              className="rounded border border-slate-200 bg-slate-50 p-3"
              key={label}
            >
              <div className="text-xs font-semibold uppercase text-slate-500">
                {label}
              </div>
              <div className="mt-1 text-lg font-bold text-slate-950">
                {value}
              </div>
            </div>
          ))}
        </div>

        <div className="tabs tabs-bordered" role="tablist">
          {tabs.map((tab) => {
            const count = data.counts[tab.id];

            return (
              <button
                aria-selected={activeTab === tab.id}
                className={`tab ${activeTab === tab.id ? 'tab-active' : ''}`}
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
          filterPlaceholder="Search project, accession, PI..."
          initialState={{ pagination: { pageSize: 25 } }}
          key={activeTab}
          tableClassName="table-zebra table-sm"
        />
      </div>
    </div>
  );
}
