import { fteColumn, LoadState, ReportSection } from './reportTables.tsx';
import type { CsvColumn } from '@/lib/csv.ts';
import { type FteOverOne, fteOverOneQueryOptions } from '@/queries/autoAssociations.ts';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

const fteOverOneColumns: ColumnDef<FteOverOne>[] = [
  { accessorKey: 'employeeId', header: 'Employee ID' },
  { accessorKey: 'employeeName', header: 'Employee' },
  fteColumn<FteOverOne>('FTE', 'fte'),
  { accessorKey: 'rowCount', header: 'Rows', meta: { cellClassName: 'text-right', headerClassName: 'text-right' } },
];

const fteOverOneCsv: CsvColumn<FteOverOne>[] = [
  { header: 'Employee ID', key: 'employeeId' },
  { header: 'Employee', key: 'employeeName' },
  { header: 'FTE', key: 'fte' },
  { header: 'Rows', key: 'rowCount' },
];

export function FteOverOneTab() {
  const { data, error, isError, isLoading } = useQuery(fteOverOneQueryOptions());
  if (isLoading || isError || !data) {
    return <LoadState error={error} isError={isError} isLoading={isLoading} label="the FTE over 1.0 report" />;
  }
  return (
    <div className="space-y-6">
      <ReportSection
        columns={fteOverOneColumns}
        csv={fteOverOneCsv}
        data={data}
        filename="auto-associations-fte-over-one.csv"
        title="Employees over 1.0 FTE"
      />
    </div>
  );
}
