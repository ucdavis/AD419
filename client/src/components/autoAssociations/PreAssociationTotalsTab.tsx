import { amountColumn, fteColumn, LoadState, ReportSection } from './reportTables.tsx';
import type { CsvColumn } from '@/lib/csv.ts';
import { type PreAssociationTotal, preAssociationTotalsQueryOptions } from '@/queries/autoAssociations.ts';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

const preAssociationTotalsColumns: ColumnDef<PreAssociationTotal>[] = [
  { accessorKey: 'orgR', header: 'OrgR' },
  { accessorKey: 'financialDepartment', header: 'Financial dept' },
  { accessorKey: 'financialDepartmentName', header: 'Name' },
  { accessorKey: 'expenseSfn', header: 'Fund SFN' },
  { accessorKey: 'sfnLabel', header: 'Fund SFN label' },
  { accessorKey: 'fteSfn', header: 'Job SFN' },
  amountColumn<PreAssociationTotal>('Expenses', 'expenses'),
  fteColumn<PreAssociationTotal>('FTE', 'fte'),
];

const preAssociationTotalsCsv: CsvColumn<PreAssociationTotal>[] = [
  { header: 'OrgR', key: 'orgR' },
  { header: 'Financial dept', key: 'financialDepartment' },
  { header: 'Name', key: 'financialDepartmentName' },
  { header: 'Fund SFN', key: 'expenseSfn' },
  { header: 'Fund SFN label', key: 'sfnLabel' },
  { header: 'Job SFN', key: 'fteSfn' },
  { format: 'currency', header: 'Expenses', key: 'expenses' },
  { header: 'FTE', key: 'fte' },
];

export function PreAssociationTotalsTab() {
  const { data, error, isError, isLoading } = useQuery(preAssociationTotalsQueryOptions());
  if (isLoading || isError || !data) {
    return <LoadState error={error} isError={isError} isLoading={isLoading} label="the pre-association totals report" />;
  }
  return (
    <div className="space-y-6">
      <ReportSection
        columns={preAssociationTotalsColumns}
        csv={preAssociationTotalsCsv}
        data={data}
        filename="auto-associations-pre-association-totals.csv"
        title="Included totals by OrgR, department, fund SFN and job SFN"
      />
    </div>
  );
}
