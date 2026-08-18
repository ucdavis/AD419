import { HttpError } from '@/lib/api.ts';
import {
  expenseReviewFilterOptionsQueryOptions,
  expenseReviewTransactionsQueryOptions,
  type ExpenseReviewCodeName,
  type ExpenseReviewFilterOption,
  type ExpenseReviewFilters,
  type ExpenseReviewIncludeState,
  type ExpenseReviewSortBy,
  type ExpenseReviewTransaction,
} from '@/queries/expenseReview.ts';
import {
  WORKFLOW_SNAPSHOT_KEY,
  updateWorkflowStageStatus,
} from '@/queries.ts';
import { DataTable } from '@/shared/dataTable.tsx';
import { useNavigate } from '@tanstack/react-router';
import {
  useMutation,
  useQuery,
  useQueryClient,
} from '@tanstack/react-query';
import type {
  ColumnDef,
  SortingState,
  Table,
  VisibilityState,
} from '@tanstack/react-table';
import { useMemo, useState } from 'react';

const PAGE_SIZE_OPTIONS = [10, 25, 50, 100];
const DEFAULT_PAGE_SIZE = 25;
const DEFAULT_SORTING: SortingState = [{ desc: false, id: 'source' }];
const FIELD_COLUMN_IDS = [
  'financialDept',
  'fund',
  'account',
  'aeProject',
  'accountingPeriod',
  'source',
  'sfn',
] as const;

const filterControls: Array<{
  id: keyof ExpenseReviewFilters;
  label: string;
  optionsKey:
    | 'accounts'
    | 'accountingPeriods'
    | 'aeProjects'
    | 'financialDepts'
    | 'funds'
    | 'sfns'
    | 'sources';
}> = [
  { id: 'financialDept', label: 'Financial Dept', optionsKey: 'financialDepts' },
  { id: 'fund', label: 'Fund', optionsKey: 'funds' },
  { id: 'account', label: 'Account', optionsKey: 'accounts' },
  { id: 'aeProject', label: 'AE Project', optionsKey: 'aeProjects' },
  {
    id: 'accountingPeriod',
    label: 'Accounting Period',
    optionsKey: 'accountingPeriods',
  },
  { id: 'source', label: 'Source', optionsKey: 'sources' },
  { id: 'sfn', label: 'SFN', optionsKey: 'sfns' },
];

function emptyFilters(): ExpenseReviewFilters {
  return {
    account: [],
    accountingPeriod: [],
    aeProject: [],
    financialDept: [],
    fund: [],
    sfn: [],
    source: [],
  };
}

function filterCount(filters: ExpenseReviewFilters) {
  return Object.values(filters).reduce((sum, values) => sum + values.length, 0);
}

function defaultSorting(): SortingState {
  return [...DEFAULT_SORTING];
}

function normalizeSorting(sorting: SortingState) {
  return sorting.length > 0 ? sorting : defaultSorting();
}

function sourceBadgeClass(source: ExpenseReviewTransaction['source']) {
  return source === 'UCP'
    ? 'badge badge-info badge-outline'
    : 'badge badge-neutral badge-outline';
}

function formatCurrency(value: number | null) {
  if (value === null) {
    return '-';
  }

  return new Intl.NumberFormat('en-US', {
    currency: 'USD',
    style: 'currency',
  }).format(value);
}

function formatFte(row: ExpenseReviewTransaction) {
  if (row.source === 'AE' || row.fte === null) {
    return '-';
  }

  return row.fte.toFixed(2);
}

function errorMessage(error: unknown, fallback: string) {
  if (error instanceof HttpError && error.body) {
    if (typeof error.body === 'string') {
      return error.body;
    }
    if (
      typeof error.body === 'object' &&
      'detail' in error.body &&
      typeof error.body.detail === 'string'
    ) {
      return error.body.detail;
    }
    if (
      typeof error.body === 'object' &&
      'title' in error.body &&
      typeof error.body.title === 'string'
    ) {
      return error.body.title;
    }

    return JSON.stringify(error.body);
  }

  return error instanceof Error ? error.message : fallback;
}

function CodeNameValue({ value }: { value: ExpenseReviewCodeName }) {
  if (!value.code) {
    return <span className="text-base-content/40">-</span>;
  }

  return (
    <span
      className="tooltip tooltip-right underline decoration-dotted cursor-help"
      data-tip={value.name ?? value.code}
    >
      {value.code}
    </span>
  );
}

function NullableTooltipValue({
  label,
  value,
}: {
  label: string | null;
  value: string | null;
}) {
  if (!value) {
    return <span className="text-base-content/40">-</span>;
  }

  return (
    <span
      className="tooltip tooltip-right underline decoration-dotted cursor-help"
      data-tip={label ?? value}
    >
      {value}
    </span>
  );
}

function buildColumns(): ColumnDef<ExpenseReviewTransaction>[] {
  return [
    {
      accessorFn: (row) => row.financialDept.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.financialDept} />,
      header: 'Financial Dept',
      id: 'financialDept',
    },
    {
      accessorFn: (row) => row.fund.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.fund} />,
      header: 'Fund',
      id: 'fund',
    },
    {
      accessorFn: (row) => row.account.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.account} />,
      header: 'Account',
      id: 'account',
    },
    {
      accessorFn: (row) => row.aeProject.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.aeProject} />,
      header: 'AE Project',
      id: 'aeProject',
    },
    {
      accessorKey: 'accountingPeriod',
      cell: ({ row }) => row.original.accountingPeriod ?? '-',
      header: 'Accounting Period',
      id: 'accountingPeriod',
    },
    {
      accessorKey: 'source',
      cell: ({ row }) => (
        <span className={sourceBadgeClass(row.original.source)}>
          {row.original.source}
        </span>
      ),
      header: 'Source',
      id: 'source',
    },
    {
      accessorFn: (row) => row.sfn ?? '',
      cell: ({ row }) => (
        <NullableTooltipValue
          label={row.original.sfnLabel}
          value={row.original.sfn}
        />
      ),
      header: 'SFN',
      id: 'sfn',
    },
    {
      accessorKey: 'amount',
      cell: ({ row }) => formatCurrency(row.original.amount),
      header: 'Amount',
      id: 'amount',
      meta: { cellClassName: 'text-right', headerClassName: 'text-right' },
    },
    {
      accessorKey: 'fte',
      cell: ({ row }) => formatFte(row.original),
      header: 'FTE',
      id: 'fte',
      meta: { cellClassName: 'text-right', headerClassName: 'text-right' },
    },
    {
      accessorKey: 'included',
      cell: ({ row }) => (
        <span
          className={
            row.original.included
              ? 'badge badge-success badge-outline'
              : 'badge badge-error badge-outline'
          }
        >
          {row.original.included ? 'Included' : 'Excluded'}
        </span>
      ),
      enableSorting: false,
      header: 'Include State',
      id: 'included',
    },
  ];
}

function IncludeStateToggle({
  counts,
  includeState,
  onChange,
}: {
  counts?: { all: number; excluded: number; included: number };
  includeState: ExpenseReviewIncludeState;
  onChange: (state: ExpenseReviewIncludeState) => void;
}) {
  const options: Array<{ label: string; state: ExpenseReviewIncludeState }> = [
    { label: 'All', state: 'all' },
    { label: 'Included', state: 'included' },
    { label: 'Excluded', state: 'excluded' },
  ];

  return (
    <div aria-label="Include state" className="join" role="group">
      {options.map((option) => (
        <button
          aria-pressed={includeState === option.state}
          className={`btn join-item btn-sm ${
            includeState === option.state ? 'btn-primary' : 'btn-outline'
          }`}
          key={option.state}
          onClick={() => onChange(option.state)}
          type="button"
        >
          {option.label}
          <span className="badge badge-sm ml-1">
            {counts?.[option.state] ?? 0}
          </span>
        </button>
      ))}
    </div>
  );
}

function FilterSelect({
  disabled,
  label,
  onAdd,
  options,
  selected,
}: {
  disabled: boolean;
  label: string;
  onAdd: (value: string) => void;
  options: ExpenseReviewFilterOption[];
  selected: string[];
}) {
  const availableOptions = options.filter(
    (option) => !selected.includes(option.value)
  );

  return (
    <label className="form-control w-full">
      <span className="label-text">{label}</span>
      <select
        aria-label={`${label} filter`}
        className="select select-bordered select-sm w-full"
        disabled={disabled || availableOptions.length === 0}
        onChange={(event) => {
          if (event.target.value) {
            onAdd(event.target.value);
            event.target.value = '';
          }
        }}
        value=""
      >
        <option value="">Any</option>
        {availableOptions.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

function SelectedFilters({
  filters,
  onClearAll,
  onRemove,
}: {
  filters: ExpenseReviewFilters;
  onClearAll: () => void;
  onRemove: (filter: keyof ExpenseReviewFilters, value: string) => void;
}) {
  const count = filterCount(filters);

  if (count === 0) {
    return (
      <div className="text-sm text-base-content/60">No filters applied</div>
    );
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      {filterControls.flatMap((control) =>
        filters[control.id].map((value) => (
          <button
            className="badge badge-outline gap-1"
            key={`${control.id}:${value}`}
            onClick={() => onRemove(control.id, value)}
            type="button"
          >
            {control.label}: {value}
            <span aria-hidden="true">x</span>
          </button>
        ))
      )}
      <button className="btn btn-ghost btn-xs" onClick={onClearAll} type="button">
        Clear all
      </button>
    </div>
  );
}

function ColumnVisibilityControls({
  table,
}: {
  table: Table<ExpenseReviewTransaction>;
}) {
  const shownCount = FIELD_COLUMN_IDS.filter((columnId) =>
    table.getColumn(columnId)?.getIsVisible()
  ).length;
  const allFieldsShown = shownCount === FIELD_COLUMN_IDS.length;

  return (
    <div className="flex flex-wrap items-center justify-end gap-2">
      <span className="text-sm text-base-content/70">
        {shownCount} of {FIELD_COLUMN_IDS.length} shown
      </span>
      {!allFieldsShown ? (
        <button
          className="btn btn-ghost btn-xs"
          onClick={() => table.resetColumnVisibility()}
          type="button"
        >
          Show all
        </button>
      ) : null}
      <details className="dropdown dropdown-end">
        <summary className="btn btn-outline btn-sm">Columns</summary>
        <div className="menu dropdown-content bg-base-100 rounded-box z-10 mt-2 w-64 border p-2 shadow">
          {FIELD_COLUMN_IDS.map((columnId) => {
            const column = table.getColumn(columnId);

            return (
              <label className="label cursor-pointer gap-3" key={columnId}>
                <span className="label-text">
                  {String(column?.columnDef.header ?? columnId)}
                </span>
                <input
                  checked={column?.getIsVisible() ?? false}
                  className="checkbox checkbox-sm"
                  onChange={(event) =>
                    column?.toggleVisibility(event.target.checked)
                  }
                  type="checkbox"
                />
              </label>
            );
          })}
        </div>
      </details>
    </div>
  );
}

export function ExpenseReviewStage() {
  const [includeState, setIncludeState] =
    useState<ExpenseReviewIncludeState>('all');
  const [filters, setFilters] = useState<ExpenseReviewFilters>(() =>
    emptyFilters()
  );
  const [pageIndex, setPageIndex] = useState(0);
  const [pageSize, setPageSize] = useState(DEFAULT_PAGE_SIZE);
  const [sorting, setSorting] = useState<SortingState>(() => defaultSorting());
  const [columnVisibility, setColumnVisibility] = useState<VisibilityState>({});
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const filterOptionsQuery = useQuery(expenseReviewFilterOptionsQueryOptions());
  const sort = sorting[0];
  const transactionsQuery = useQuery(
    expenseReviewTransactionsQueryOptions({
      filters,
      includeState,
      page: pageIndex + 1,
      pageSize,
      sortBy: (sort?.id as ExpenseReviewSortBy | undefined) ?? 'source',
      sortDirection: sort?.desc ? 'desc' : 'asc',
    })
  );
  const continueMutation = useMutation({
    mutationFn: () => updateWorkflowStageStatus('expense-review', 'Complete'),
    onSuccess: (snapshot) => {
      queryClient.setQueryData(WORKFLOW_SNAPSHOT_KEY, snapshot);
      void navigate({
        params: { stageId: 'auto-associations' },
        to: '/workflow/$stageId',
      });
    },
  });
  const columns = useMemo(() => buildColumns(), []);
  const counts = transactionsQuery.data?.counts;
  const activeFilterCount = filterCount(filters);
  const filterOptions = filterOptionsQuery.data;

  const resetToFirstPage = () => setPageIndex(0);
  const addFilter = (filter: keyof ExpenseReviewFilters, value: string) => {
    setFilters((current) => ({
      ...current,
      [filter]: current[filter].includes(value)
        ? current[filter]
        : [...current[filter], value],
    }));
    resetToFirstPage();
  };
  const removeFilter = (filter: keyof ExpenseReviewFilters, value: string) => {
    setFilters((current) => ({
      ...current,
      [filter]: current[filter].filter((candidate) => candidate !== value),
    }));
    resetToFirstPage();
  };
  const clearFilters = () => {
    setFilters(emptyFilters());
    resetToFirstPage();
  };
  const handleIncludeStateChange = (state: ExpenseReviewIncludeState) => {
    setIncludeState(state);
    resetToFirstPage();
  };

  if (filterOptionsQuery.isLoading || transactionsQuery.isLoading) {
    return <p>Loading expense review transactions...</p>;
  }

  if (filterOptionsQuery.isError || transactionsQuery.isError) {
    const error = filterOptionsQuery.error ?? transactionsQuery.error;

    return (
      <div className="alert alert-error items-start" role="alert">
        <div>
          <h2 className="font-bold">Unable to load expense review</h2>
          <p>
            {errorMessage(
              error,
              'The all transactions table could not be loaded.'
            )}
          </p>
          <button
            className="btn btn-sm mt-3"
            disabled={filterOptionsQuery.isFetching || transactionsQuery.isFetching}
            onClick={() => {
              void filterOptionsQuery.refetch();
              void transactionsQuery.refetch();
            }}
            type="button"
          >
            {filterOptionsQuery.isFetching || transactionsQuery.isFetching
              ? 'Retrying...'
              : 'Retry'}
          </button>
        </div>
      </div>
    );
  }

  const transactions = transactionsQuery.data;
  if (!transactions) {
    return <p>Loading expense review transactions...</p>;
  }

  return (
    <div className="space-y-4">
      <div className="tabs tabs-bordered" role="tablist">
        <button
          aria-selected="true"
          className="tab tab-active"
          role="tab"
          type="button"
        >
          All Transactions
          <span className="badge badge-sm ml-2">{counts?.all ?? 0}</span>
        </button>
        <button
          aria-disabled="true"
          className="tab tab-disabled"
          disabled
          role="tab"
          type="button"
        >
          By Financial Dept
        </button>
        <button
          aria-disabled="true"
          className="tab tab-disabled"
          disabled
          role="tab"
          type="button"
        >
          By SFN
        </button>
      </div>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <IncludeStateToggle
          counts={counts}
          includeState={includeState}
          onChange={handleIncludeStateChange}
        />
        <div className="text-sm text-base-content/70">
          {transactions.totalCount.toLocaleString()} transactions
        </div>
      </div>

      <div className="space-y-3">
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          {filterControls.map((control) => (
            <FilterSelect
              disabled={filterOptionsQuery.isFetching}
              key={control.id}
              label={control.label}
              onAdd={(value) => addFilter(control.id, value)}
              options={filterOptions?.[control.optionsKey] ?? []}
              selected={filters[control.id]}
            />
          ))}
        </div>
        <SelectedFilters
          filters={filters}
          onClearAll={clearFilters}
          onRemove={removeFilter}
        />
        {activeFilterCount > 0 ? (
          <div className="text-xs text-base-content/60">
            Showing rows matching {activeFilterCount} selected filter
            {activeFilterCount === 1 ? '' : 's'}.
          </div>
        ) : null}
      </div>

      {transactionsQuery.isFetching ? (
        <div className="text-sm text-base-content/60" role="status">
          Refreshing transactions...
        </div>
      ) : null}

      <DataTable
        columns={columns}
        columnVisibility={columnVisibility}
        data={transactions.rows}
        globalFilter="none"
        manualPagination
        manualSorting
        onColumnVisibilityChange={setColumnVisibility}
        onPageIndexChange={setPageIndex}
        onPageSizeChange={(nextPageSize) => {
          setPageSize(nextPageSize);
          setPageIndex(0);
        }}
        onSortingChange={(nextSorting) => {
          setSorting(normalizeSorting(nextSorting));
          setPageIndex(0);
        }}
        pageCount={transactions.pageCount}
        pageIndex={pageIndex}
        pageSize={pageSize}
        pageSizeOptions={PAGE_SIZE_OPTIONS}
        rowCount={transactions.totalCount}
        sorting={sorting}
        tableActions={(table) => <ColumnVisibilityControls table={table} />}
      />

      <div className="flex flex-col gap-3 border-t pt-4 sm:flex-row sm:items-center sm:justify-between">
        <span className="text-sm text-base-content/70">
          Confirm the right transactions are included before triggering
          auto-associations.
        </span>
        <button
          className="btn btn-primary"
          disabled={continueMutation.isPending}
          onClick={() => continueMutation.mutate()}
          type="button"
        >
          {continueMutation.isPending
            ? 'Continuing...'
            : 'Continue to Auto-Associations'}
        </button>
      </div>
      {continueMutation.isError ? (
        <div className="alert alert-error" role="alert">
          <span>
            {errorMessage(
              continueMutation.error,
              'Could not update the workflow stage.'
            )}
          </span>
        </div>
      ) : null}
    </div>
  );
}
