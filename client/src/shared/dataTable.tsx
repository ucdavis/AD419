import { useEffect, useState, type ReactNode } from 'react';
import {
  ColumnDef,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  InitialTableState,
  type OnChangeFn,
  type PaginationState,
  type RowData,
  type SortingState,
  type Table,
  type Updater,
  type VisibilityState,
  useReactTable,
} from '@tanstack/react-table';

declare module '@tanstack/react-table' {
  interface ColumnMeta<TData extends RowData, TValue> {
    cellClassName?: string;
    headerClassName?: string;
  }
}

type TableActionsRenderer<TData extends object> =
  | ReactNode
  | ((table: Table<TData>) => ReactNode);

interface DataTableProps<TData extends object> {
  cellClassName?: string;
  columns: ColumnDef<TData>[];
  columnVisibility?: VisibilityState;
  data: TData[];
  filterPlaceholder?: string;
  globalFilter?: 'left' | 'right' | 'none'; // Controls the position of the search box
  headerClassName?: string;
  initialState?: InitialTableState; // Optional initial state for the table, use for stuff like setting page size or sorting
  manualPagination?: boolean;
  manualSorting?: boolean;
  onColumnVisibilityChange?: (columnVisibility: VisibilityState) => void;
  onPageIndexChange?: (pageIndex: number) => void;
  onPageSizeChange?: (pageSize: number) => void;
  onSortingChange?: (sorting: SortingState) => void;
  pageCount?: number;
  pageIndex?: number;
  pageSize?: number;
  pageSizeOptions?: number[];
  rowCount?: number;
  sorting?: SortingState;
  tableActions?: TableActionsRenderer<TData>;
  tableClassName?: string;
}

function applyUpdater<T>(updater: Updater<T>, current: T): T {
  return typeof updater === 'function'
    ? (updater as (previous: T) => T)(current)
    : updater;
}

export const DataTable = <TData extends object>({
  cellClassName,
  columns,
  columnVisibility,
  data,
  filterPlaceholder = 'Search all columns...',
  globalFilter = 'right',
  headerClassName,
  initialState,
  manualPagination = false,
  manualSorting = false,
  onColumnVisibilityChange,
  onPageIndexChange,
  onPageSizeChange,
  onSortingChange,
  pageCount: manualPageCount,
  pageIndex,
  pageSize,
  pageSizeOptions = [10, 25, 50, 100],
  rowCount,
  sorting,
  tableActions,
  tableClassName = 'table-zebra',
}: DataTableProps<TData>) => {
  const [pageInputValue, setPageInputValue] = useState('');
  const [internalColumnVisibility, setInternalColumnVisibility] =
    useState<VisibilityState>(initialState?.columnVisibility ?? {});
  const [internalPagination, setInternalPagination] =
    useState<PaginationState>({
      pageIndex: initialState?.pagination?.pageIndex ?? 0,
      pageSize: initialState?.pagination?.pageSize ?? 10,
    });
  const [internalSorting, setInternalSorting] = useState<SortingState>(
    initialState?.sorting ?? []
  );
  const resolvedColumnVisibility =
    columnVisibility ?? internalColumnVisibility;
  const resolvedPagination = {
    pageIndex: pageIndex ?? internalPagination.pageIndex,
    pageSize: pageSize ?? internalPagination.pageSize,
  };
  const resolvedSorting = sorting ?? internalSorting;
  const handleColumnVisibilityChange: OnChangeFn<VisibilityState> = (
    updater
  ) => {
    const nextColumnVisibility = applyUpdater(
      updater,
      resolvedColumnVisibility
    );

    if (columnVisibility === undefined) {
      setInternalColumnVisibility(nextColumnVisibility);
    }
    onColumnVisibilityChange?.(nextColumnVisibility);
  };
  const handlePaginationChange: OnChangeFn<PaginationState> = (updater) => {
    const nextPagination = applyUpdater(updater, resolvedPagination);

    if (pageIndex === undefined || pageSize === undefined) {
      setInternalPagination({
        pageIndex:
          pageIndex === undefined
            ? nextPagination.pageIndex
            : resolvedPagination.pageIndex,
        pageSize:
          pageSize === undefined
            ? nextPagination.pageSize
            : resolvedPagination.pageSize,
      });
    }

    if (nextPagination.pageIndex !== resolvedPagination.pageIndex) {
      onPageIndexChange?.(nextPagination.pageIndex);
    }
    if (nextPagination.pageSize !== resolvedPagination.pageSize) {
      onPageSizeChange?.(nextPagination.pageSize);
    }
  };
  const handleSortingChange: OnChangeFn<SortingState> = (updater) => {
    const nextSorting = applyUpdater(updater, resolvedSorting);

    if (sorting === undefined) {
      setInternalSorting(nextSorting);
    }
    onSortingChange?.(nextSorting);
  };

  // TanStack Table is not yet marked compatible with the React Compiler.
  // Keep this suppression until the library compatibility guidance changes.
  // eslint-disable-next-line react-hooks/incompatible-library
  const table = useReactTable({
    autoResetPageIndex: false, // keep the current page when data updates in place
    columns,
    data,
    getCoreRowModel: getCoreRowModel(), // basic rendering
    getFilteredRowModel: getFilteredRowModel(), // enable filtering feature
    getPaginationRowModel: getPaginationRowModel(), // enable pagination calculations
    getSortedRowModel: getSortedRowModel(), // enable sorting feature
    initialState: {
      ...initialState,
    },
    manualPagination,
    manualSorting,
    onColumnVisibilityChange: handleColumnVisibilityChange,
    onPaginationChange: handlePaginationChange,
    onSortingChange: handleSortingChange,
    pageCount: manualPageCount,
    rowCount,
    state: {
      columnVisibility: resolvedColumnVisibility,
      pagination: resolvedPagination,
      sorting: resolvedSorting,
    },
  });

  const filterControl =
    globalFilter === 'none' ? null : (
      <label className="input input-bordered flex items-center gap-2 w-full max-w-sm">
        <svg
          className="h-[1em] opacity-50"
          viewBox="0 0 24 24"
          xmlns="http://www.w3.org/2000/svg"
        >
          <g
            fill="none"
            stroke="currentColor"
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="2.5"
          >
            <circle cx="11" cy="11" r="8"></circle>
            <path d="m21 21-4.3-4.3"></path>
          </g>
        </svg>
        <input
          className="grow"
          onChange={(e) => table.setGlobalFilter(e.target.value)}
          placeholder={filterPlaceholder}
          type="text"
          value={table.getState().globalFilter ?? ''}
        />
        {table.getState().globalFilter && (
          <button
            className="btn btn-ghost btn-sm btn-circle"
            onClick={() => table.setGlobalFilter('')}
            type="button"
          >
            <svg
              className="h-4 w-4"
              fill="currentColor"
              viewBox="0 0 16 16"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path d="M5.28 4.22a.75.75 0 0 0-1.06 1.06L6.94 8l-2.72 2.72a.75.75 0 1 0 1.06 1.06L8 9.06l2.72 2.72a.75.75 0 1 0 1.06-1.06L9.06 8l2.72-2.72a.75.75 0 0 0-1.06-1.06L8 6.94 5.28 4.22Z" />
            </svg>
          </button>
        )}
      </label>
    );

  const resolvedTableActions =
    typeof tableActions === 'function' ? tableActions(table) : tableActions;

  const toolbarItems =
    globalFilter === 'left'
      ? [filterControl, resolvedTableActions]
      : [resolvedTableActions, filterControl];
  const hasToolbar = toolbarItems.some(Boolean);
  const pageCount = table.getPageCount();
  const currentPage =
    pageCount === 0 ? 0 : table.getState().pagination.pageIndex + 1;
  const currentPageSize = table.getState().pagination.pageSize;
  const selectablePageSizes = Array.from(
    new Set([...pageSizeOptions, currentPageSize])
  ).sort((a, b) => a - b);

  useEffect(() => {
    setPageInputValue(currentPage === 0 ? '' : String(currentPage));
  }, [currentPage]);

  return (
    <div className="space-y-4">
      {hasToolbar && (
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          {toolbarItems.map((item, index) =>
            item ? <div key={index}>{item}</div> : null
          )}
        </div>
      )}

      <div className="overflow-x-auto">
        {' '}
        {/* enables horizontal scroll on small screens */}
        <table className={`table w-full ${tableClassName}`}>
          <thead>
            {table.getHeaderGroups().map((headerGroup) => (
              <tr key={headerGroup.id}>
                {headerGroup.headers.map((header) => (
                  <th
                    className={[
                      'cursor-pointer',
                      headerClassName,
                      header.column.columnDef.meta?.headerClassName,
                    ]
                      .filter(Boolean)
                      .join(' ')}
                    key={header.id}
                    onClick={header.column.getToggleSortingHandler?.()}
                  >
                    {header.isPlaceholder
                      ? null
                      : flexRender(
                          header.column.columnDef.header,
                          header.getContext()
                        )}
                    {/* Add sort indicator if column is sorted */}
                    {header.column.getIsSorted() === 'asc'
                      ? ' 🔼'
                      : header.column.getIsSorted() === 'desc'
                        ? ' 🔽'
                        : ''}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map((row) => (
              <tr key={row.id}>
                {row.getVisibleCells().map((cell) => (
                  <td
                    className={[
                      cellClassName,
                      cell.column.columnDef.meta?.cellClassName,
                    ]
                      .filter(Boolean)
                      .join(' ')}
                    key={cell.id}
                  >
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
        <div className="flex flex-col gap-3 py-3 sm:flex-row sm:items-center sm:justify-between">
          <label className="flex items-center gap-2 text-sm">
            <span>Rows per page</span>
            <select
              aria-label="Rows per page"
              className="select select-bordered select-xs w-20"
              onChange={(event) => table.setPageSize(Number(event.target.value))}
              value={currentPageSize}
            >
              {selectablePageSizes.map((pageSize) => (
                <option key={pageSize} value={pageSize}>
                  {pageSize}
                </option>
              ))}
            </select>
          </label>

          <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-end">
            <label className="flex items-center gap-2 text-sm">
              <span>Page</span>
              <input
                aria-label="Page"
                className="input input-bordered input-xs w-20"
                disabled={pageCount === 0}
                max={Math.max(pageCount, 1)}
                min={1}
                onBlur={() => {
                  setPageInputValue(
                    currentPage === 0 ? '' : String(currentPage)
                  );
                }}
                onChange={(event) => {
                  const { value } = event.target;
                  setPageInputValue(value);

                  if (value === '') {
                    return;
                  }

                  const pageNumber = Number(value);

                  if (!Number.isInteger(pageNumber)) {
                    return;
                  }

                  table.setPageIndex(
                    Math.min(Math.max(pageNumber, 1), pageCount) - 1
                  );
                }}
                type="number"
                value={pageInputValue}
              />
              <span>of {pageCount}</span>
            </label>

            <div className="join">
              <button
                className="btn join-item btn-xs"
                disabled={!table.getCanPreviousPage()}
                onClick={() => table.setPageIndex(0)}
                type="button"
              >
                First
              </button>
              <button
                className="btn join-item btn-xs"
                disabled={!table.getCanPreviousPage()}
                onClick={() => table.previousPage()}
                type="button"
              >
                Previous
              </button>
              <button
                className="btn join-item btn-xs"
                disabled={!table.getCanNextPage()}
                onClick={() => table.nextPage()}
                type="button"
              >
                Next
              </button>
              <button
                className="btn join-item btn-xs"
                disabled={!table.getCanNextPage()}
                onClick={() => table.setPageIndex(pageCount - 1)}
                type="button"
              >
                Last
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
