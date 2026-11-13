import { amountColumn, fteColumn, LoadState, ReportSection } from './reportTables.tsx';
import type { CsvColumn } from '@/lib/csv.ts';
import { type PiFteAdjustment, piFteAdjustmentsQueryOptions } from '@/queries/autoAssociations.ts';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

const piFteAdjustmentColumns: ColumnDef<PiFteAdjustment>[] = [
  { accessorKey: 'employeeId', header: 'Employee ID' },
  { accessorKey: 'employeeName', header: 'Employee' },
  { accessorKey: 'jobCode', header: 'Job code' },
  { accessorKey: 'titleName', header: 'Title' },
  { accessorKey: 'titleFteSfn', header: 'Was' },
  { accessorKey: 'fteSfn', header: 'Now' },
  amountColumn<PiFteAdjustment>('Expenses', 'expenses'),
  fteColumn<PiFteAdjustment>('FTE', 'fte'),
  { accessorKey: 'rowCount', header: 'Rows', meta: { cellClassName: 'text-right', headerClassName: 'text-right' } },
];

const piFteAdjustmentCsv: CsvColumn<PiFteAdjustment>[] = [
  { header: 'Employee ID', key: 'employeeId' },
  { header: 'Employee', key: 'employeeName' },
  { header: 'Job code', key: 'jobCode' },
  { header: 'Title', key: 'titleName' },
  { header: 'Was', key: 'titleFteSfn' },
  { header: 'Now', key: 'fteSfn' },
  { format: 'currency', header: 'Expenses', key: 'expenses' },
  { header: 'FTE', key: 'fte' },
  { header: 'Rows', key: 'rowCount' },
];

export function PiFteAdjustmentsTab() {
  const { data, error, isError, isLoading } = useQuery(piFteAdjustmentsQueryOptions());
  if (isLoading || isError || !data) {
    return <LoadState error={error} isError={isError} isLoading={isLoading} label="the PI FTE report" />;
  }
  return (
    <div className="space-y-6">
      <ReportSection
        columns={piFteAdjustmentColumns}
        csv={piFteAdjustmentCsv}
        data={data}
        filename="auto-associations-pi-fte-adjustments.csv"
        title="PI payroll moved to line 241"
      />
    </div>
  );
}
