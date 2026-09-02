import { HttpError } from '@/lib/api.ts';
import {
  buildExpenseReviewTransactionsCsvUrl,
  expenseReviewFilterOptionsQueryOptions,
  expenseReviewTransactionsQueryOptions,
  type ExpenseReviewCodeName,
  type ExpenseReviewExclusionReason,
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
import { ExportEndpointButton } from '@/shared/exportDataButton.tsx';
import { useNavigate } from '@tanstack/react-router';
import {
  useMutation,
  useQuery,
  useQueryClient,
} from '@tanstack/react-query';
import type { ColumnDef, SortingState } from '@tanstack/react-table';
import { useMemo, useState } from 'react';

const PAGE_SIZE_OPTIONS = [10, 25, 50, 100];
const DEFAULT_PAGE_SIZE = 25;
const DEFAULT_SORTING: SortingState = [{ desc: false, id: 'source' }];

const filterControls: Array<{
  id: keyof ExpenseReviewFilters;
  label: string;
  optionsKey:
    | 'accounts'
    | 'accountingPeriods'
    | 'activities'
    | 'aeProjects'
    | 'entities'
    | 'exclusionReasons'
    | 'financialDepts'
    | 'funds'
    | 'programs'
    | 'purposes'
    | 'sfns'
    | 'sources';
}> = [
  { id: 'source', label: 'Source', optionsKey: 'sources' },
  { id: 'entity', label: 'Entity', optionsKey: 'entities' },
  { id: 'fund', label: 'Fund', optionsKey: 'funds' },
  { id: 'financialDept', label: 'Financial Dept', optionsKey: 'financialDepts' },
  { id: 'account', label: 'Account', optionsKey: 'accounts' },
  { id: 'purpose', label: 'Purpose', optionsKey: 'purposes' },
  { id: 'program', label: 'Program', optionsKey: 'programs' },
  { id: 'aeProject', label: 'Project', optionsKey: 'aeProjects' },
  { id: 'activity', label: 'Activity', optionsKey: 'activities' },
  {
    id: 'accountingPeriod',
    label: 'Accounting Period',
    optionsKey: 'accountingPeriods',
  },
  { id: 'sfn', label: 'SFN', optionsKey: 'sfns' },
  {
    id: 'exclusionReason',
    label: 'Exclusion Reason',
    optionsKey: 'exclusionReasons',
  },
];

function emptyFilters(): ExpenseReviewFilters {
  return {
    account: [],
    accountingPeriod: [],
    activity: [],
    aeProject: [],
    entity: [],
    exclusionReason: [],
    financialDept: [],
    fund: [],
    program: [],
    purpose: [],
    sfn: [],
    source: [],
  };
}

function filterCount(filters: ExpenseReviewFilters) {
  return Object.values(filters).reduce((sum, values) => sum + values.length, 0);
}

function activeFilterCount(
  filters: ExpenseReviewFilters,
  includeState: ExpenseReviewIncludeState
) {
  return filterCount(filters) + (includeState === 'all' ? 0 : 1);
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

function formatReasonCurrency(value: number) {
  return new Intl.NumberFormat('en-US', {
    currency: 'USD',
    style: 'currency',
  }).format(value);
}

function formatRowCount(rowCount: number) {
  return rowCount === 1 ? '1 row' : `${rowCount} rows`;
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

function ExclusionReasonChips({
  reasons,
}: {
  reasons: ExpenseReviewExclusionReason[];
}) {
  if (reasons.length === 0) {
    return <span className="text-base-content/40">-</span>;
  }

  return (
    <div className="flex min-w-72 flex-wrap gap-1.5">
      {reasons.map((reason) => (
        <span
          className="badge badge-outline h-auto max-w-96 justify-start whitespace-normal py-1 text-left leading-tight"
          key={reason.code}
        >
          {reason.label} · {formatReasonCurrency(reason.amount)} ·{' '}
          {formatRowCount(reason.rowCount)}
        </span>
      ))}
    </div>
  );
}

function buildColumns(displayByPeriod: boolean): ColumnDef<ExpenseReviewTransaction>[] {
  const columns: ColumnDef<ExpenseReviewTransaction>[] = [
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
      accessorFn: (row) => row.entity.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.entity} />,
      header: 'Entity',
      id: 'entity',
    },
    {
      accessorFn: (row) => row.fund.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.fund} />,
      header: 'Fund',
      id: 'fund',
    },
    {
      accessorFn: (row) => row.financialDept.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.financialDept} />,
      header: 'Financial Dept',
      id: 'financialDept',
    },
    {
      accessorFn: (row) => row.account.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.account} />,
      header: 'Account',
      id: 'account',
    },
    {
      accessorFn: (row) => row.purpose.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.purpose} />,
      header: 'Purpose',
      id: 'purpose',
    },
    {
      accessorFn: (row) => row.program.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.program} />,
      header: 'Program',
      id: 'program',
    },
    {
      accessorFn: (row) => row.aeProject.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.aeProject} />,
      header: 'Project',
      id: 'aeProject',
    },
    {
      accessorFn: (row) => row.activity.code ?? '',
      cell: ({ row }) => <CodeNameValue value={row.original.activity} />,
      header: 'Activity',
      id: 'activity',
    },
  ];

  if (displayByPeriod) {
    columns.push({
      accessorKey: 'accountingPeriod',
      cell: ({ row }) => row.original.accountingPeriod ?? '-',
      header: 'Accounting Period',
      id: 'accountingPeriod',
    });
  }

  columns.push(
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
      header: 'Include State',
      id: 'included',
    },
    {
      accessorFn: (row) => row.exclusionReasons.map((reason) => reason.code),
      cell: ({ row }) => (
        <ExclusionReasonChips reasons={row.original.exclusionReasons} />
      ),
      enableSorting: false,
      header: 'Exclusion Reasons',
      id: 'exclusionReason',
    },
  );

  return columns;
}

function IncludeStateSelect({
  counts,
  disabled,
  includeState,
  onChange,
}: {
  counts?: { all: number; excluded: number; included: number };
  disabled: boolean;
  includeState: ExpenseReviewIncludeState;
  onChange: (state: ExpenseReviewIncludeState) => void;
}) {
  const options: Array<{ label: string; state: ExpenseReviewIncludeState }> = [
    { label: 'All', state: 'all' },
    { label: 'Included', state: 'included' },
    { label: 'Excluded', state: 'excluded' },
  ];

  return (
    <label className="form-control w-full">
      <span className="label-text">Include State</span>
      <select
        aria-label="Include State filter"
        className="select select-bordered select-sm w-full"
        disabled={disabled}
        onChange={(event) =>
          onChange(event.target.value as ExpenseReviewIncludeState)
        }
        value={includeState}
      >
        {options.map((option) => (
          <option key={option.state} value={option.state}>
            {option.label} ({counts?.[option.state] ?? 0})
          </option>
        ))}
      </select>
    </label>
  );
}

function DisplayByPeriodToggle({
  checked,
  disabled,
  onChange,
}: {
  checked: boolean;
  disabled: boolean;
  onChange: (checked: boolean) => void;
}) {
  return (
    <label className="label w-full cursor-pointer justify-start gap-3 self-end rounded border border-base-300 px-3 py-2">
      <input
        aria-label="Display by period"
        checked={checked}
        className="toggle toggle-sm"
        disabled={disabled}
        onChange={(event) => onChange(event.target.checked)}
        type="checkbox"
      />
      <span className="label-text">Display by period</span>
    </label>
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
  includeState,
  onClearAll,
  onIncludeStateChange,
  onRemove,
}: {
  filters: ExpenseReviewFilters;
  includeState: ExpenseReviewIncludeState;
  onClearAll: () => void;
  onIncludeStateChange: (state: ExpenseReviewIncludeState) => void;
  onRemove: (filter: keyof ExpenseReviewFilters, value: string) => void;
}) {
  const count = activeFilterCount(filters, includeState);

  if (count === 0) {
    return (
      <div className="text-sm text-base-content/60">No filters applied</div>
    );
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      {includeState === 'all' ? null : (
        <button
          className="badge badge-outline gap-1"
          onClick={() => onIncludeStateChange('all')}
          type="button"
        >
          Include State: {includeState === 'included' ? 'Included' : 'Excluded'}
          <span aria-hidden="true">x</span>
        </button>
      )}
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

export function ExpenseReviewStage() {
  const [includeState, setIncludeState] =
    useState<ExpenseReviewIncludeState>('all');
  const [filters, setFilters] = useState<ExpenseReviewFilters>(() =>
    emptyFilters()
  );
  const [pageIndex, setPageIndex] = useState(0);
  const [pageSize, setPageSize] = useState(DEFAULT_PAGE_SIZE);
  const [sorting, setSorting] = useState<SortingState>(() => defaultSorting());
  const [displayByPeriod, setDisplayByPeriod] = useState(false);
  const [exportError, setExportError] = useState<string | null>(null);
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const filterOptionsQuery = useQuery(expenseReviewFilterOptionsQueryOptions());
  const sort = sorting[0];
  const transactionsQuery = useQuery(
    expenseReviewTransactionsQueryOptions({
      displayByPeriod,
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
  const columns = useMemo(() => buildColumns(displayByPeriod), [displayByPeriod]);
  const exportUrl = buildExpenseReviewTransactionsCsvUrl({
    displayByPeriod,
    filters,
    includeState,
    sortBy: (sort?.id as ExpenseReviewSortBy | undefined) ?? 'source',
    sortDirection: sort?.desc ? 'desc' : 'asc',
  });
  const counts = transactionsQuery.data?.counts;
  const selectedFilterCount = activeFilterCount(filters, includeState);
  const filterOptions = filterOptionsQuery.data;

  const resetToFirstPage = () => setPageIndex(0);
  const resetExportError = () => setExportError(null);
  const addFilter = (filter: keyof ExpenseReviewFilters, value: string) => {
    setFilters((current) => ({
      ...current,
      [filter]: current[filter].includes(value)
        ? current[filter]
        : [...current[filter], value],
    }));
    resetToFirstPage();
    resetExportError();
  };
  const removeFilter = (filter: keyof ExpenseReviewFilters, value: string) => {
    setFilters((current) => ({
      ...current,
      [filter]: current[filter].filter((candidate) => candidate !== value),
    }));
    resetToFirstPage();
    resetExportError();
  };
  const clearFilters = () => {
    setIncludeState('all');
    setFilters(emptyFilters());
    resetToFirstPage();
    resetExportError();
  };
  const handleIncludeStateChange = (state: ExpenseReviewIncludeState) => {
    setIncludeState(state);
    resetToFirstPage();
    resetExportError();
  };
  const handleDisplayByPeriodChange = (checked: boolean) => {
    setDisplayByPeriod(checked);
    if (!checked && sorting[0]?.id === 'accountingPeriod') {
      setSorting(defaultSorting());
    }
    resetToFirstPage();
    resetExportError();
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
              'The grouped expense table could not be loaded.'
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
          Grouped Expenses
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

      <div className="text-sm text-base-content/70">
        {transactions.totalCount.toLocaleString()} grouped rows
      </div>

      <div className="space-y-3">
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          <IncludeStateSelect
            counts={counts}
            disabled={transactionsQuery.isFetching}
            includeState={includeState}
            onChange={handleIncludeStateChange}
          />
          <DisplayByPeriodToggle
            checked={displayByPeriod}
            disabled={transactionsQuery.isFetching}
            onChange={handleDisplayByPeriodChange}
          />
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
          includeState={includeState}
          onClearAll={clearFilters}
          onIncludeStateChange={handleIncludeStateChange}
          onRemove={removeFilter}
        />
        {selectedFilterCount > 0 ? (
          <div className="text-xs text-base-content/60">
            Showing rows matching {selectedFilterCount} selected filter
            {selectedFilterCount === 1 ? '' : 's'}.
          </div>
        ) : null}
      </div>

      {transactionsQuery.isFetching ? (
        <div className="text-sm text-base-content/60" role="status">
          Refreshing grouped expenses...
        </div>
      ) : null}

      <DataTable
        columns={columns}
        data={transactions.rows}
        globalFilter="none"
        manualPagination
        manualSorting
        onPageIndexChange={setPageIndex}
        onPageSizeChange={(nextPageSize) => {
          setPageSize(nextPageSize);
          setPageIndex(0);
        }}
        onSortingChange={(nextSorting) => {
          setSorting(normalizeSorting(nextSorting));
          setPageIndex(0);
          resetExportError();
        }}
        pageCount={transactions.pageCount}
        pageIndex={pageIndex}
        pageSize={pageSize}
        pageSizeOptions={PAGE_SIZE_OPTIONS}
        rowCount={transactions.totalCount}
        sorting={sorting}
      />

      <div className="flex flex-col gap-3 border-t pt-4 sm:flex-row sm:items-center sm:justify-between">
        <span className="text-sm text-base-content/70">
          Confirm the right expenses are included before triggering
          auto-associations.
        </span>
        <div className="flex flex-wrap items-center gap-2">
          <ExportEndpointButton
            className="btn-outline"
            disabled={transactionsQuery.isFetching}
            filename="expense-review-transactions.csv"
            label="Export CSV"
            onError={(error) =>
              setExportError(
                errorMessage(error, 'The CSV export could not be downloaded.')
              )
            }
            onSuccess={() => setExportError(null)}
            pendingLabel="Exporting..."
            url={exportUrl}
          />
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
      </div>
      {exportError ? (
        <div className="alert alert-error" role="alert">
          <span>{exportError}</span>
        </div>
      ) : null}
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
