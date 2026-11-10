import { amountColumn, fteColumn, LoadState, ReportSection, unassociatedColumns, unassociatedCsv } from './reportTables.tsx';
import { formatCurrency, formatFte, type PiRuleSfn } from './autoAssociationsTabs.ts';
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

// One tab per SFN. 201, 202 and 205 share a report, so the three tabs read the
// same cached query and each shows its own slice.
export function Rule20xTab({ sfn }: { sfn: PiRuleSfn }) {
  const { data, error, isError, isLoading } = useQuery(rule20xReportQueryOptions());
  if (isLoading || isError || !data) {
    return <LoadState error={error} isError={isError} isLoading={isLoading} label={`the ${sfn} report`} />;
  }
  const report = data.sfns.find((candidate) => candidate.sfn === sfn);
  const unassociated = data.unassociated.filter((expense) => expense.expenseSfn === sfn);
  return (
    <div className="space-y-6">
      {report ? (
        <section className="space-y-2">
          <h3 className="text-lg font-semibold">
            {report.sfn}
            {report.label ? ` ${report.label}` : ''}: {formatCurrency(report.expenses)}, {formatFte(report.fte)} FTE
            across {report.projectCount} projects
          </h3>
          <ReportSection
            columns={piColumns}
            csv={piCsv}
            data={report.pis}
            filename={`auto-associations-${sfn}-by-pi.csv`}
            title="By PI"
          />
        </section>
      ) : null}
      <ReportSection
        columns={unassociatedColumns}
        csv={unassociatedCsv}
        data={unassociated}
        filename={`auto-associations-${sfn}-unassociated.csv`}
        title="Not associated"
      />
    </div>
  );
}
