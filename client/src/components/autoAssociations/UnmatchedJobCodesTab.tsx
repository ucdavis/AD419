import { amountColumn, fteColumn, LoadState, ReportSection } from './reportTables.tsx';
import type { CsvColumn } from '@/lib/csv.ts';
import { type UnmatchedJobCode, unmatchedJobCodesQueryOptions } from '@/queries/autoAssociations.ts';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

const unmatchedJobCodesColumns: ColumnDef<UnmatchedJobCode>[] = [
  { accessorKey: 'jobCode', header: 'Job code' },
  { accessorKey: 'titleName', header: 'Title' },
  { accessorKey: 'staffTypeCode', header: 'Staff type' },
  { accessorKey: 'reason', header: 'Reason' },
  { accessorKey: 'rowCount', header: 'Rows', meta: { cellClassName: 'text-right', headerClassName: 'text-right' } },
  { accessorKey: 'employeeCount', header: 'Employees', meta: { cellClassName: 'text-right', headerClassName: 'text-right' } },
  amountColumn<UnmatchedJobCode>('Amount', 'amount'),
  fteColumn<UnmatchedJobCode>('FTE', 'fte'),
];

const unmatchedJobCodesCsv: CsvColumn<UnmatchedJobCode>[] = [
  { header: 'Job code', key: 'jobCode' },
  { header: 'Title', key: 'titleName' },
  { header: 'Staff type', key: 'staffTypeCode' },
  { header: 'Reason', key: 'reason' },
  { header: 'Rows', key: 'rowCount' },
  { header: 'Employees', key: 'employeeCount' },
  { format: 'currency', header: 'Amount', key: 'amount' },
  { header: 'FTE', key: 'fte' },
];

export function UnmatchedJobCodesTab() {
  const { data, error, isError, isLoading } = useQuery(unmatchedJobCodesQueryOptions());
  if (isLoading || isError || !data) {
    return <LoadState error={error} isError={isError} isLoading={isLoading} label="the unmatched job codes report" />;
  }
  return (
    <div className="space-y-6">
      <ReportSection
        columns={unmatchedJobCodesColumns}
        csv={unmatchedJobCodesCsv}
        data={data}
        filename="auto-associations-unmatched-job-codes.csv"
        title="Job codes with no FTE line"
      />
    </div>
  );
}
