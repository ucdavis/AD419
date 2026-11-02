import {
  ExpenseReviewTransactionDialog,
  defaultDetailVisibility,
} from './ExpenseReviewTransactionDialog.tsx';
import { FilterTypeahead } from '@/components/expenseReview/FilterTypeahead.tsx';
import { HttpError } from '@/lib/api.ts';
import {
  EMPTY_EXPENSE_REVIEW_FILTERS,
  buildExpenseReviewTransactionsCsvUrl,
  expenseReviewFilterOptionsQueryOptions,
  expenseReviewTransactionsQueryOptions,
  type ExpenseReviewCodeName,
  type ExpenseReviewExclusionReason,
  type ExpenseReviewFilterOptionsResponse,
  type ExpenseReviewFilters,
  type ExpenseReviewIncludeState,
  type ExpenseReviewSortBy,
  type ExpenseReviewTransaction,
} from '@/queries/expenseReview.ts';
import { WORKFLOW_SNAPSHOT_KEY, updateWorkflowStageStatus } from '@/queries.ts';
import { DataTable } from '@/shared/dataTable.tsx';
import { ExportEndpointButton } from '@/shared/exportDataButton.tsx';
import {
  DEFAULT_EXPENSE_REVIEW_PAGE_SIZE,
  EXPENSE_REVIEW_PAGE_SIZES,
  filtersToSearch,
  resolveExpenseReviewView,
  type ExpenseReviewSearch,
} from './expenseReviewSearch.ts';
import { getRouteApi, useNavigate } from '@tanstack/react-router';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type {
  CellContext,
  ColumnDef,
  SortingState,
  VisibilityState,
} from '@tanstack/react-table';
import { createContext, useContext, useState } from 'react';

const TransactionDetailsOpenerContext = createContext<
  (group: ExpenseReviewTransaction, opener: HTMLElement) => void
>(() => {});
function TransactionDetailsButton({
  row,
}: CellContext<ExpenseReviewTransaction, unknown>) {
  const open = useContext(TransactionDetailsOpenerContext);
  return (
    <button
      className="btn btn-ghost btn-xs"
      onClick={(event) => open(row.original, event.currentTarget)}
      type="button"
    >
      View transactions
    </button>
  );
}
const DETAILS_COLUMN: ColumnDef<ExpenseReviewTransaction> = {
  cell: TransactionDetailsButton,
  enableSorting: false,
  header: 'Details',
  id: 'details',
};

const routeApi = getRouteApi('/(authenticated)/workflow/$stageId');

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
  {
    id: 'financialDept',
    label: 'Financial Dept',
    optionsKey: 'financialDepts',
  },
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

function filterCount(filters: ExpenseReviewFilters) {
  return Object.values(filters).reduce((sum, values) => sum + values.length, 0);
}

function activeFilterCount(
  filters: ExpenseReviewFilters,
  includeState: ExpenseReviewIncludeState
) {
  return filterCount(filters) + (includeState === 'all' ? 0 : 1);
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
          {reason.label}
        </span>
      ))}
    </div>
  );
}

function buildColumns(
  displayByPeriod: boolean
): ColumnDef<ExpenseReviewTransaction>[] {
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
    }
  );

  return columns;
}

const FLAT_COLUMNS = buildColumns(false);
const PERIOD_COLUMNS = buildColumns(true);

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

function IncludeZeroAmountsToggle({
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
        aria-label="Include $0 groups"
        checked={checked}
        className="toggle toggle-sm"
        disabled={disabled}
        onChange={(event) => onChange(event.target.checked)}
        type="checkbox"
      />
      <span className="label-text">Include $0 groups</span>
    </label>
  );
}

function SelectedFilters({
  filterOptions,
  filters,
  includeState,
  onClearAll,
  onIncludeStateChange,
  onRemove,
}: {
  filterOptions: ExpenseReviewFilterOptionsResponse;
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
        filters[control.id].map((value) => {
          const label =
            filterOptions[control.optionsKey].find(
              (option) => option.value === value
            )?.label ?? value;

          return (
            <button
              className="badge badge-outline gap-1"
              key={`${control.id}:${value}`}
              onClick={() => onRemove(control.id, value)}
              type="button"
            >
              {control.label}: {label}
              <span aria-hidden="true">x</span>
            </button>
          );
        })
      )}
      <button
        className="btn btn-ghost btn-xs"
        onClick={onClearAll}
        type="button"
      >
        Clear all
      </button>
    </div>
  );
}

export function ExpenseReviewStage() {
  const search = routeApi.useSearch();
  const navigateSearch = routeApi.useNavigate();
  const view = resolveExpenseReviewView(search);
  const {
    displayByPeriod,
    filters,
    includeState,
    includeZeroAmounts,
    page,
    pageSize,
    sortBy,
    sortDirection,
  } = view;
  const sorting: SortingState = [
    { desc: sortDirection === 'desc', id: sortBy },
  ];
  const [exportError, setExportError] = useState<string | null>(null);
  const detailContext = {
    displayByPeriod,
    filters,
    includeState,
    includeZeroAmounts,
  };
  const detailContextKey = JSON.stringify(detailContext);
  const [selectedGroup, setSelectedGroup] = useState<{
    contextKey: string;
    group: ExpenseReviewTransaction;
    opener: HTMLElement | null;
  } | null>(null);
  const [detailVisibility, setDetailVisibility] = useState<
    Record<'AE' | 'UCP', VisibilityState>
  >({ AE: defaultDetailVisibility('AE'), UCP: defaultDetailVisibility('UCP') });
  if (selectedGroup && selectedGroup.contextKey !== detailContextKey) {
    setSelectedGroup(null);
  }
  const openGroup = (
    group: ExpenseReviewTransaction,
    opener: HTMLElement | null
  ) => {
    setSelectedGroup({ contextKey: detailContextKey, group, opener });
  };
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const filterOptionsQuery = useQuery(expenseReviewFilterOptionsQueryOptions());
  const setSearch = (patch: ExpenseReviewSearch) => {
    void navigateSearch({
      replace: true,
      search: (previous: ExpenseReviewSearch) => ({ ...previous, ...patch }),
      to: '.',
    });
  };
  const transactionsQuery = useQuery(
    expenseReviewTransactionsQueryOptions({
      displayByPeriod,
      filters,
      includeState,
      includeZeroAmounts,
      page,
      pageSize,
      sortBy,
      sortDirection,
    })
  );
  const continueMutation = useMutation({
    mutationFn: () => updateWorkflowStageStatus('expense-review', 'Complete'),
    onSuccess: (snapshot) => {
      queryClient.setQueryData(WORKFLOW_SNAPSHOT_KEY, snapshot);
      void navigate({
        params: { stageId: 'orgr-review' },
        to: '/workflow/$stageId',
      });
    },
  });
  const columns = [
    ...(displayByPeriod ? PERIOD_COLUMNS : FLAT_COLUMNS),
    DETAILS_COLUMN,
  ];
  const exportUrl = buildExpenseReviewTransactionsCsvUrl({
    displayByPeriod,
    filters,
    includeState,
    includeZeroAmounts,
    sortBy,
    sortDirection,
  });
  const counts = transactionsQuery.data?.counts;
  const selectedFilterCount = activeFilterCount(filters, includeState);
  const filterOptions = filterOptionsQuery.data;

  const resetExportError = () => setExportError(null);
  const applyFilters = (
    update: (current: ExpenseReviewFilters) => ExpenseReviewFilters,
    nextIncludeState: ExpenseReviewIncludeState
  ) => {
    void navigateSearch({
      replace: true,
      search: (previous: ExpenseReviewSearch) => ({
        ...previous,
        ...filtersToSearch(
          update(resolveExpenseReviewView(previous).filters),
          nextIncludeState
        ),
      }),
    });
    resetExportError();
  };
  const addFilter = (filter: keyof ExpenseReviewFilters, value: string) =>
    applyFilters(
      (current) => ({
        ...current,
        [filter]: current[filter].includes(value)
          ? current[filter]
          : [...current[filter], value],
      }),
      includeState
    );
  const removeFilter = (filter: keyof ExpenseReviewFilters, value: string) =>
    applyFilters(
      (current) => ({
        ...current,
        [filter]: current[filter].filter((candidate) => candidate !== value),
      }),
      includeState
    );
  const clearFilters = () =>
    applyFilters(() => EMPTY_EXPENSE_REVIEW_FILTERS, 'all');
  const handleIncludeStateChange = (state: ExpenseReviewIncludeState) =>
    applyFilters((current) => current, state);
  const handleDisplayByPeriodChange = (checked: boolean) => {
    setSearch({
      byPeriod: checked ? true : undefined,
      dir: !checked && sortBy === 'accountingPeriod' ? undefined : search.dir,
      page: undefined,
      sort: !checked && sortBy === 'accountingPeriod' ? undefined : search.sort,
    });
    resetExportError();
  };
  const handleIncludeZeroAmountsChange = (checked: boolean) => {
    setSearch({ page: undefined, zero: checked ? true : undefined });
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
            disabled={
              filterOptionsQuery.isFetching || transactionsQuery.isFetching
            }
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
  if (!transactions || !filterOptions) {
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
          <IncludeZeroAmountsToggle
            checked={includeZeroAmounts}
            disabled={transactionsQuery.isFetching}
            onChange={handleIncludeZeroAmountsChange}
          />
          {filterControls.map((control) => (
            <FilterTypeahead
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
          filterOptions={filterOptions}
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

      <TransactionDetailsOpenerContext.Provider value={openGroup}>
        <DataTable
          columns={columns}
          data={transactions.rows}
          globalFilter="none"
          manualPagination
          manualSorting
          onPageIndexChange={(pageIndex) =>
            setSearch({ page: pageIndex === 0 ? undefined : pageIndex + 1 })
          }
          onPageSizeChange={(nextPageSize) =>
            setSearch({
              page: undefined,
              size:
                nextPageSize === DEFAULT_EXPENSE_REVIEW_PAGE_SIZE
                  ? undefined
                  : (nextPageSize as ExpenseReviewSearch['size']),
            })
          }
          onRowClick={(row, event) =>
            openGroup(row, event.currentTarget.querySelector('button'))
          }
          onSortingChange={(nextSorting) => {
            const next = nextSorting[0];
            setSearch({
              dir: next?.desc ? 'desc' : undefined,
              page: undefined,
              sort:
                next && next.id !== 'source'
                  ? (next.id as ExpenseReviewSortBy)
                  : undefined,
            });
            resetExportError();
          }}
          pageCount={transactions.pageCount}
          pageIndex={page - 1}
          pageSize={pageSize}
          pageSizeOptions={[...EXPENSE_REVIEW_PAGE_SIZES]}
          rowCount={transactions.totalCount}
          sorting={sorting}
        />
      </TransactionDetailsOpenerContext.Provider>

      {selectedGroup && selectedGroup.contextKey === detailContextKey ? (
        <ExpenseReviewTransactionDialog
          context={detailContext}
          group={selectedGroup.group}
          key={selectedGroup.group.id}
          onClose={() => setSelectedGroup(null)}
          onVisibilityChange={(value) =>
            setDetailVisibility((current) => ({
              ...current,
              [selectedGroup.group.source]: value,
            }))
          }
          opener={selectedGroup.opener}
          visibility={detailVisibility[selectedGroup.group.source]}
        />
      ) : null}

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
              : 'Continue to OrgR Review'}
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
