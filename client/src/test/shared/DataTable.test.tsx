import { render, screen, within } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { DataTable } from '@/shared/dataTable.tsx';
import type { ColumnDef, SortingState } from '@tanstack/react-table';

interface TestRow {
  name: string;
  status: string;
}

const columns: ColumnDef<TestRow>[] = [
  {
    accessorKey: 'name',
    header: 'Name',
  },
  {
    accessorKey: 'status',
    header: 'Status',
  },
];

function makeRows(count: number): TestRow[] {
  return Array.from({ length: count }, (_, index) => ({
    name: `Row ${index + 1}`,
    status: index % 2 === 0 ? 'Included' : 'Excluded',
  }));
}

describe('DataTable', () => {
  it('keeps existing client-side pagination behavior', async () => {
    const user = userEvent.setup();

    render(
      <DataTable
        columns={columns}
        data={makeRows(12)}
        initialState={{ pagination: { pageSize: 5 } }}
      />
    );

    expect(screen.getByText('Row 1')).toBeInTheDocument();
    expect(screen.queryByText('Row 6')).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Next' }));

    expect(screen.queryByText('Row 1')).not.toBeInTheDocument();
    expect(screen.getByText('Row 6')).toBeInTheDocument();
  });

  it('renders the provided manual page count', () => {
    render(
      <DataTable
        columns={columns}
        data={makeRows(2)}
        manualPagination
        pageCount={8}
        pageIndex={2}
        pageSize={2}
      />
    );

    expect(screen.getByLabelText('Page')).toHaveValue(3);
    expect(screen.getByText('of 8')).toBeInTheDocument();
  });

  it('calls the page callback when manual pagination changes', async () => {
    const user = userEvent.setup();
    const onPageIndexChange = vi.fn();

    render(
      <DataTable
        columns={columns}
        data={makeRows(2)}
        manualPagination
        onPageIndexChange={onPageIndexChange}
        pageCount={3}
        pageIndex={0}
        pageSize={2}
      />
    );

    await user.click(screen.getByRole('button', { name: 'Next' }));

    expect(onPageIndexChange).toHaveBeenCalledWith(1);
  });

  it('calls the page size callback when manual page size changes', async () => {
    const user = userEvent.setup();
    const onPageSizeChange = vi.fn();

    render(
      <DataTable
        columns={columns}
        data={makeRows(10)}
        manualPagination
        onPageSizeChange={onPageSizeChange}
        pageCount={5}
        pageIndex={0}
        pageSize={2}
        pageSizeOptions={[2, 5]}
      />
    );

    await user.selectOptions(screen.getByLabelText('Rows per page'), ['5']);

    expect(onPageSizeChange).toHaveBeenCalledWith(5);
  });

  it('calls the sorting callback when manual sorting changes', async () => {
    const user = userEvent.setup();
    const onSortingChange = vi.fn();

    render(
      <DataTable
        columns={columns}
        data={makeRows(2)}
        manualSorting
        onSortingChange={onSortingChange}
        sorting={[] satisfies SortingState}
      />
    );

    await user.click(screen.getByRole('columnheader', { name: 'Name' }));

    expect(onSortingChange).toHaveBeenCalledWith([{ desc: false, id: 'name' }]);
  });

  it('hides and shows columns through table column visibility state', async () => {
    const user = userEvent.setup();

    render(
      <DataTable
        columns={columns}
        data={makeRows(1)}
        tableActions={(table) => (
          <button
            onClick={() => table.getColumn('status')?.toggleVisibility()}
            type="button"
          >
            Toggle status
          </button>
        )}
      />
    );

    expect(screen.getByRole('columnheader', { name: 'Status' })).toBeVisible();

    await user.click(screen.getByRole('button', { name: 'Toggle status' }));

    expect(
      screen.queryByRole('columnheader', { name: 'Status' })
    ).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Toggle status' }));

    expect(screen.getByRole('columnheader', { name: 'Status' })).toBeVisible();
  });

  it('keeps existing global filtering behavior for local tables', async () => {
    const user = userEvent.setup();

    render(
      <DataTable
        columns={columns}
        data={[
          { name: 'Alpha project', status: 'Included' },
          { name: 'Beta project', status: 'Excluded' },
        ]}
      />
    );

    await user.type(
      screen.getByPlaceholderText('Search all columns...'),
      'alpha'
    );

    const body = screen.getAllByRole('rowgroup')[1];

    expect(within(body).getByText('Alpha project')).toBeInTheDocument();
    expect(within(body).queryByText('Beta project')).not.toBeInTheDocument();
  });
});
