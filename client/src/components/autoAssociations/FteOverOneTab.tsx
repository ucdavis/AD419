import { fteColumn, LoadState, ReportSection } from './reportTables.tsx';
import {
  defaultDetailVisibility,
  ExpenseReviewTransactionDialog,
} from '@/components/expenseReview/ExpenseReviewTransactionDialog.tsx';
import type { CsvColumn } from '@/lib/csv.ts';
import {
  type FteOverOne,
  fteOverOneQueryOptions,
} from '@/queries/autoAssociations.ts';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef, VisibilityState } from '@tanstack/react-table';
import { useMemo, useState } from 'react';

const payrollExpenseGroupsLabel = 'Payroll expense groups';

const fteOverOneColumns: ColumnDef<FteOverOne>[] = [
  { accessorKey: 'employeeId', header: 'Employee ID' },
  { accessorKey: 'employeeName', header: 'Employee' },
  fteColumn<FteOverOne>('FTE', 'fte'),
  {
    accessorKey: 'rowCount',
    header: payrollExpenseGroupsLabel,
    meta: { cellClassName: 'text-right', headerClassName: 'text-right' },
  },
];

const fteOverOneCsv: CsvColumn<FteOverOne>[] = [
  { header: 'Employee ID', key: 'employeeId' },
  { header: 'Employee', key: 'employeeName' },
  { header: 'FTE', key: 'fte' },
  { header: payrollExpenseGroupsLabel, key: 'rowCount' },
];

export function FteOverOneTab({ buildId }: { buildId: number }) {
  const { data, error, isError, isLoading } = useQuery(
    fteOverOneQueryOptions()
  );
  const [selected, setSelected] = useState<{
    employee: FteOverOne;
    opener: HTMLElement;
  } | null>(null);
  const [visibility, setVisibility] = useState<VisibilityState>(() =>
    defaultDetailVisibility('UCP', true)
  );
  const columns = useMemo<ColumnDef<FteOverOne>[]>(
    () => [
      ...fteOverOneColumns,
      {
        cell: ({ row }) => (
          <button
            aria-label={`View transactions for ${row.original.employeeName ?? row.original.employeeId}`}
            className="btn btn-ghost btn-sm"
            onClick={(event) =>
              setSelected({
                employee: row.original,
                opener: event.currentTarget,
              })
            }
            type="button"
          >
            View transactions
          </button>
        ),
        enableSorting: false,
        header: 'Details',
        id: 'details',
      },
    ],
    []
  );
  if (isLoading || isError || !data) {
    return (
      <LoadState
        error={error}
        isError={isError}
        isLoading={isLoading}
        label="the FTE over 1.1 report"
      />
    );
  }
  return (
    <div className="space-y-6">
      <ReportSection
        columns={columns}
        csv={fteOverOneCsv}
        data={data}
        description="Each group combines payroll transactions that share the same reporting fields. Select View transactions to see the individual entries."
        filename="auto-associations-fte-over-1.1.csv"
        title="Employees over 1.1 FTE"
      />
      {selected ? (
        <ExpenseReviewTransactionDialog
          buildId={buildId}
          employee={{ ...selected.employee, reportFte: selected.employee.fte }}
          mode="employee"
          onClose={() => setSelected(null)}
          onVisibilityChange={setVisibility}
          opener={selected.opener}
          visibility={visibility}
        />
      ) : null}
    </div>
  );
}
