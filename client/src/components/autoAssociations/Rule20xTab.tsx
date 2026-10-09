import { amountColumn, fteColumn, LoadState, ReportSection, unassociatedColumns, unassociatedCsv } from './reportTables.tsx';
import { formatCurrency, formatFte } from './autoAssociationsTabs.ts';
import type { CsvColumn } from '@/lib/csv.ts';
import { type Rule20xPi, rule20xReportQueryOptions } from '@/queries/autoAssociations.ts';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

const piColumns: ColumnDef<Rule20xPi>[] = [
  { accessorKey: 'employeeId', header: 'Employee ID' },
  { accessorKey: 'employeeName', header: 'PI' },
  { accessorKey: 'projectCount', header: 'Projects', meta: { cellClassName: 'text-right', headerClassName: 'text-right' } },
  amountColumn<Rule20xPi>('Expenses', 'expenses'),
  fteColumn<Rule20xPi>('FTE', 'fte'),
];

const piCsv: CsvColumn<Rule20xPi>[] = [
  { header: 'Employee ID', key: 'employeeId' },
  { header: 'PI', key: 'employeeName' },
  { header: 'Projects', key: 'projectCount' },
  { format: 'currency', header: 'Expenses', key: 'expenses' },
  { header: 'FTE', key: 'fte' },
];

export function Rule20xTab() {
  const { data, error, isError, isLoading } = useQuery(rule20xReportQueryOptions());
  if (isLoading || isError || !data) {
    return <LoadState error={error} isError={isError} isLoading={isLoading} label="the 201/202/205 report" />;
  }
  return (
    <div className="space-y-6">
      {data.sfns.map((sfn) => (
        <section className="space-y-2" key={sfn.sfn}>
          <h3 className="text-lg font-semibold">
            {sfn.sfn}
            {sfn.label ? ` ${sfn.label}` : ''}: {formatCurrency(sfn.expenses)}, {formatFte(sfn.fte)} FTE across{' '}
            {sfn.projectCount} projects
          </h3>
          <ReportSection
            columns={piColumns}
            csv={piCsv}
            data={sfn.pis}
            filename={`auto-associations-${sfn.sfn}-by-pi.csv`}
            title="By PI"
          />
        </section>
      ))}
      <ReportSection
        columns={unassociatedColumns}
        csv={unassociatedCsv}
        data={data.unassociated}
        filename="auto-associations-20x-unassociated.csv"
        title="Not associated"
      />
    </div>
  );
}
