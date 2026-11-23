import {
  buildExpenseReviewDetailCsvUrl,
  expenseReviewDetailQueryOptions,
  type ExpenseReviewDetailParams,
  type ExpenseReviewDetailResponse,
  type ExpenseReviewDetailSortBy,
  type ExpenseReviewEmployeeDetailSortBy,
  type ExpenseReviewEmployeeScope,
  type ExpenseReviewTransaction,
  type ExpenseReviewTransactionDetail,
  type ExpenseReviewTransactionsCsvParams,
} from '@/queries/expenseReview.ts';
import { DataTable } from '@/shared/dataTable.tsx';
import { ExportEndpointButton } from '@/shared/exportDataButton.tsx';
import { useQuery } from '@tanstack/react-query';
import type {
  ColumnDef,
  SortingState,
  VisibilityState,
} from '@tanstack/react-table';
import { useEffect, useId, useRef, useState } from 'react';

export const defaultDetailVisibility = (
  source: 'AE' | 'UCP',
  employee = false
): VisibilityState =>
  Object.fromEntries(
    (source === 'UCP'
      ? [
          'jobCode',
          'hours',
          'id',
          ...(employee
            ? [
                'entity',
                'account',
                'purpose',
                'program',
                'activity',
                'orgR',
                'expenseSfn',
                'fteSfn',
              ]
            : ['calculatedFte']),
        ]
      : ['documentType', 'journalReference', 'id']
    ).map((id) => [id, false])
  );

const currency = (amount: number | null) =>
  amount == null
    ? '—'
    : amount.toLocaleString('en-US', {
        currency: 'USD',
        maximumFractionDigits: 4,
        minimumFractionDigits: 2,
        style: 'currency',
      });

function detailColumns(
  source: 'AE' | 'UCP',
  employee = false
): ColumnDef<ExpenseReviewTransactionDetail>[] {
  const field = (
    id: ExpenseReviewEmployeeDetailSortBy,
    header: string
  ): ColumnDef<ExpenseReviewTransactionDetail> => ({
    accessorKey: id,
    cell: ({ row }) => row.original[id] ?? '—',
    header,
    id,
  });
  return [
    {
      ...field(
        'transactionDate',
        source === 'UCP' ? 'Pay End Date' : 'Journal accounting date'
      ),
      cell: ({ row }) => row.original.transactionDate?.slice(0, 10) ?? '—',
    },
    ...(source === 'UCP'
      ? [
          {
            ...field('ucEarnEndDate', 'UC Earn End Date'),
            cell: ({
              row,
            }: {
              row: { original: ExpenseReviewTransactionDetail };
            }) => row.original.ucEarnEndDate?.slice(0, 10) ?? '—',
          },
          field('transactionId', 'Transaction ID'),
        ]
      : []),
    field('accountingPeriod', 'Accounting period'),
    ...(source === 'UCP'
      ? [
          field('employeeId', 'Employee ID'),
          field('employeeName', 'Employee name'),
          field('positionNumber', 'Position number'),
          {
            ...field('ernCode', 'Earnings code'),
            cell: ({
              row,
            }: {
              row: { original: ExpenseReviewTransactionDetail };
            }) => (
              <span title={row.original.ernDescription ?? undefined}>
                {row.original.ernCode ?? '—'}
              </span>
            ),
          },
          field('salaryFringe', 'Salary/fringe'),
        ]
      : [
          field('accountingSequenceNumber', 'Accounting sequence number'),
          field('journalName', 'Journal name'),
          field('lineDescription', 'Line description'),
        ]),
    {
      ...field('amount', 'Amount'),
      cell: ({ row }) => currency(row.original.amount),
    },
    ...(employee
      ? [
          field('calculatedFte', 'Calculated FTE'),
          field('reportFteContribution', 'Report FTE contribution'),
          field('reportStatus', 'Report status'),
          field('entity', 'Entity'),
          field('financialDepartment', 'Financial Dept'),
          field('fund', 'Fund'),
          field('account', 'Account'),
          field('project', 'Project'),
          field('purpose', 'Purpose'),
          field('program', 'Program'),
          field('activity', 'Activity'),
          field('orgR', 'OrgR'),
          field('expenseSfn', 'Expense SFN'),
          field('fteSfn', 'FTE SFN'),
        ]
      : []),
    {
      accessorKey: 'exclusionReasons',
      cell: ({ row }) =>
        row.original.exclusionReasons
          .map((reason) => reason.label)
          .join('; ') || '—',
      enableSorting: false,
      header: 'Exclusion reasons',
      id: 'exclusionReasons',
    },
    ...(source === 'UCP'
      ? [
          field('jobCode', 'Job code'),
          field('hours', 'Hours'),
          ...(employee ? [] : [field('calculatedFte', 'Calculated FTE')]),
          field('id', 'Labor transaction ID'),
        ]
      : [
          field('documentType', 'Document type'),
          field('journalReference', 'Journal reference'),
          field('id', 'Transaction ID'),
        ]),
  ];
}
const columnsBySource = { AE: detailColumns('AE'), UCP: detailColumns('UCP') };
const employeeColumns = detailColumns('UCP', true);

type DialogProps = {
  onClose: () => void;
  onVisibilityChange: (value: VisibilityState) => void;
  opener: HTMLElement | null;
  visibility: VisibilityState;
} & (
  | {
      context: ExpenseReviewTransactionsCsvParams;
      group: ExpenseReviewTransaction;
      mode?: 'group';
    }
  | {
      buildId: number;
      employee: {
        employeeId: string;
        employeeName: string | null;
        reportFte: number;
      };
      mode: 'employee';
    }
);

export function ExpenseReviewTransactionDialog(props: DialogProps) {
  // Remount the dialog state when its subject changes, including a rebuilt report.
  const subjectKey =
    props.mode === 'employee'
      ? `employee:${props.buildId}:${props.employee.employeeId}`
      : `group:${props.group.id}`;
  return <TransactionDialogContent key={subjectKey} {...props} />;
}

function TransactionDialogContent(props: DialogProps) {
  const { onClose, onVisibilityChange, opener, visibility } = props;
  const employeeMode = props.mode === 'employee';
  const source = employeeMode ? 'UCP' : props.group.source;
  const dialogRef = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const [draft, setDraft] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);
  const [sorting, setSorting] = useState<SortingState>([
    { desc: false, id: 'transactionDate' },
  ]);
  const [exportError, setExportError] = useState<string | null>(null);
  const [scope, setScope] = useState<ExpenseReviewEmployeeScope>('report');
  const paging = {
    page,
    pageSize,
    search,
    sortDirection: sorting[0]?.desc ? ('desc' as const) : ('asc' as const),
  };
  const params: ExpenseReviewDetailParams = employeeMode
    ? {
        ...paging,
        buildId: props.buildId,
        employeeId: props.employee.employeeId,
        kind: 'employee',
        scope,
        sortBy: (sorting[0]?.id ??
          'transactionDate') as ExpenseReviewEmployeeDetailSortBy,
      }
    : {
        ...paging,
        context: props.context,
        groupId: props.group.id,
        kind: 'group',
        sortBy: (sorting[0]?.id ??
          'transactionDate') as ExpenseReviewDetailSortBy,
      };
  const query = useQuery(expenseReviewDetailQueryOptions(params));
  const columns = employeeMode ? employeeColumns : columnsBySource[source];
  const data = query.data;
  // Retain totals during search/paging, but never across transaction scopes.
  const [lastData, setLastData] = useState<{
    data: ExpenseReviewDetailResponse;
    scope: ExpenseReviewEmployeeScope;
  } | null>(null);
  if (data && data !== lastData?.data) {
    setLastData({ data, scope });
  }
  const fullContext =
    data ?? (lastData?.scope === scope ? lastData.data : null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) {
      return;
    }
    dialog.showModal();
    return () => {
      dialog.close();
      if (opener?.isConnected) {
        opener.focus();
      }
    };
  }, [opener]);

  const applySearch = (value: string) => {
    setSearch(value.trim());
    setPage(1);
    setExportError(null);
  };
  const displayedGroup =
    fullContext && 'group' in fullContext
      ? fullContext.group
      : employeeMode
        ? null
        : props.group;
  const displayedEmployee =
    fullContext && 'employeeId' in fullContext
      ? fullContext
      : employeeMode
        ? props.employee
        : null;
  const count = fullContext?.transactionCount;

  return (
    <dialog
      aria-labelledby={titleId}
      className="modal"
      onCancel={(event) => {
        event.preventDefault();
        onClose();
      }}
      onKeyDown={(event) => {
        if (event.key !== 'Tab') {
          return;
        }
        const dialog = event.currentTarget;
        const controls = [
          ...dialog.querySelectorAll<HTMLElement>(
            ':is(button, input, select, textarea, summary, a[href], [tabindex="0"]):not(:disabled)'
          ),
        ].filter((element) => element.getClientRects().length > 0);
        const first = controls[0];
        const last = controls.at(-1);
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last?.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first?.focus();
        }
      }}
      ref={dialogRef}
    >
      <div className="modal-box flex max-h-[92dvh] w-[96vw] max-w-[100rem] flex-col gap-4 overflow-y-auto">
        <div className="flex items-center justify-between gap-4">
          <h2 className="text-xl font-bold" id={titleId}>
            Transaction details · {source}
          </h2>
          <button
            autoFocus
            className="btn btn-sm"
            onClick={onClose}
            type="button"
          >
            Close
          </button>
        </div>
        <div className="space-y-1 text-sm">
          <p>
            {fullContext
              ? `${fullContext.fiscalYear} · ${fullContext.cycleStart} – ${fullContext.cycleEnd}`
              : 'Fiscal cycle loading…'}{' '}
            · {source}
            {displayedGroup
              ? ` · ${displayedGroup.included ? 'Included' : 'Excluded'}`
              : ''}
          </p>
          {displayedEmployee ? (
            <>
              <p>
                Employee:{' '}
                {[displayedEmployee.employeeId, displayedEmployee.employeeName]
                  .filter(Boolean)
                  .join(' · ')}
              </p>
              <p>Report FTE: {displayedEmployee.reportFte.toFixed(6)}</p>
              <p>
                Report FTE contribution shows the FTE counted in this report.
                Calculated FTE is the original payroll value.
              </p>
            </>
          ) : null}
          {displayedGroup ? (
            <dl className="grid grid-cols-1 gap-x-6 gap-y-1 sm:grid-cols-2 lg:grid-cols-3">
              {(
                [
                  ['Entity', displayedGroup.entity],
                  ['Financial Dept', displayedGroup.financialDept],
                  ['Fund', displayedGroup.fund],
                  ['Account', displayedGroup.account],
                  ['Project', displayedGroup.aeProject],
                  ['Purpose', displayedGroup.purpose],
                  ['Program', displayedGroup.program],
                  ['Activity', displayedGroup.activity],
                ] as const
              ).map(([label, value]) => (
                <div className="min-w-0 wrap-anywhere" key={label}>
                  <dt className="inline font-semibold">{label}:</dt>{' '}
                  <dd className="inline">
                    {[value.code, value.name].filter(Boolean).join(' · ') ||
                      '—'}
                  </dd>
                </div>
              ))}
              <div className="min-w-0 wrap-anywhere">
                <dt className="inline font-semibold">SFN:</dt>{' '}
                <dd className="inline">
                  {[displayedGroup.sfn, displayedGroup.sfnLabel]
                    .filter(Boolean)
                    .join(' · ') || '—'}
                </dd>
              </div>
              {!employeeMode && props.context.displayByPeriod ? (
                <div className="min-w-0 wrap-anywhere">
                  <dt className="inline font-semibold">
                    Group accounting period:
                  </dt>{' '}
                  <dd className="inline">
                    {displayedGroup.accountingPeriod ?? '—'}
                  </dd>
                </div>
              ) : null}
            </dl>
          ) : null}
          <p>
            {employeeMode
              ? scope === 'report'
                ? 'Report rows'
                : 'All in-cycle rows'
              : 'Full group'}
            : {count?.toLocaleString() ?? '…'} transactions ·{' '}
            {currency(
              displayedGroup?.amount ??
                (fullContext && 'totalAmount' in fullContext
                  ? fullContext.totalAmount
                  : null)
            )}
          </p>
          {search && data ? (
            <p role="status">
              Matching: {data.matchingCount.toLocaleString()} transactions ·{' '}
              {currency(data.matchingAmount)}
            </p>
          ) : null}
        </div>
        {employeeMode ? (
          <fieldset className="flex flex-wrap gap-4">
            <legend className="mb-1 text-sm font-semibold">
              Transactions to show
            </legend>
            {(
              [
                ['report', 'Report rows only'],
                ['all', 'All in-cycle rows'],
              ] as const
            ).map(([value, label]) => (
              <label className="flex items-center gap-2 text-sm" key={value}>
                <input
                  checked={scope === value}
                  className="radio radio-sm"
                  name={`${titleId}-scope`}
                  onChange={() => {
                    setScope(value);
                    setPage(1);
                    setExportError(null);
                  }}
                  type="radio"
                  value={value}
                />
                {label}
              </label>
            ))}
          </fieldset>
        ) : null}
        <form
          className="flex flex-wrap items-end gap-2"
          onSubmit={(event) => {
            event.preventDefault();
            applySearch(draft);
          }}
        >
          <label className="flex flex-col gap-1 text-sm">
            Search transactions
            <input
              className="input input-bordered input-sm"
              maxLength={500}
              onChange={(event) => setDraft(event.target.value)}
              value={draft}
            />
          </label>
          <button className="btn btn-sm" type="submit">
            Search
          </button>
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => {
              setDraft('');
              applySearch('');
            }}
            type="button"
          >
            Clear
          </button>
        </form>
        <details>
          <summary className="cursor-pointer text-sm font-semibold">
            Columns
          </summary>
          <div className="flex flex-wrap gap-3 py-2">
            {columns.map((column) => (
              <label
                className="flex items-center gap-2 text-sm"
                key={column.id}
              >
                <input
                  checked={visibility[column.id!] !== false}
                  className="checkbox checkbox-sm"
                  onChange={(event) =>
                    onVisibilityChange({
                      ...visibility,
                      [column.id!]: event.target.checked,
                    })
                  }
                  type="checkbox"
                />
                {String(column.header)}
              </label>
            ))}
            <button
              className="btn btn-ghost btn-xs"
              onClick={() =>
                onVisibilityChange(
                  defaultDetailVisibility(source, employeeMode)
                )
              }
              type="button"
            >
              Reset columns
            </button>
          </div>
        </details>
        {query.isFetching ? <p role="status">Loading transactions…</p> : null}
        {query.isError ? (
          <div className="alert alert-error" role="alert">
            <span>Unable to load transactions. {query.error.message}</span>
            <button
              className="btn btn-sm"
              onClick={() => void query.refetch()}
              type="button"
            >
              Retry
            </button>
          </div>
        ) : null}
        {data ? (
          <>
            {data.rows.length === 0 ? (
              <p>No transactions match this search.</p>
            ) : null}
            <DataTable
              columns={columns}
              columnVisibility={visibility}
              data={data.rows}
              globalFilter="none"
              manualPagination
              manualSorting
              onPageIndexChange={(index) => setPage(index + 1)}
              onPageSizeChange={(size) => {
                setPageSize(size);
                setPage(1);
              }}
              onSortingChange={(value) => {
                setSorting(value);
                setPage(1);
                setExportError(null);
              }}
              pageCount={data.pageCount}
              pageIndex={page - 1}
              pageSize={pageSize}
              pageSizeOptions={[10, 25, 50, 100]}
              rowCount={data.matchingCount}
              sorting={sorting}
            />
          </>
        ) : null}
        <div className="flex justify-end">
          <ExportEndpointButton
            disabled={!data || query.isFetching}
            filename={
              employeeMode
                ? `employee-${props.employee.employeeId}-transactions.csv`
                : 'expense-review-transactions.csv'
            }
            label="Export transactions CSV"
            onError={() =>
              setExportError(
                'The CSV export could not be downloaded. Try exporting again.'
              )
            }
            onSuccess={() => setExportError(null)}
            url={buildExpenseReviewDetailCsvUrl(params)}
          />
        </div>
        {exportError ? (
          <p className="alert alert-error" role="alert">
            {exportError}
          </p>
        ) : null}
      </div>
    </dialog>
  );
}
