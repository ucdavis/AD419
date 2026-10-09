import { formatCurrency, formatFte } from './autoAssociationsTabs.ts';
import type { CsvColumn } from '@/lib/csv.ts';
import type { AssociatedProject, UnassociatedExpense } from '@/queries/autoAssociations.ts';
import { apiErrorMessage } from '@/queries/orgr.ts';
import { DataTable } from '@/shared/dataTable.tsx';
import { ExportDataButton } from '@/shared/exportDataButton.tsx';
import type { ColumnDef } from '@tanstack/react-table';

// Money and FTE columns are built through these helpers so a prior-year
// column can later be added beside each without touching row shapes.
export function amountColumn<T extends object>(header: string, key: keyof T & string): ColumnDef<T> {
  return {
    accessorKey: key,
    cell: ({ getValue }) => formatCurrency(getValue<number>()),
    header,
    meta: { cellClassName: 'text-right tabular-nums', headerClassName: 'text-right' },
  };
}

export function fteColumn<T extends object>(header: string, key: keyof T & string): ColumnDef<T> {
  return {
    accessorKey: key,
    cell: ({ getValue }) => formatFte(getValue<number>()),
    header,
    meta: { cellClassName: 'text-right tabular-nums', headerClassName: 'text-right' },
  };
}

export const associatedProjectColumns: ColumnDef<AssociatedProject>[] = [
  { accessorKey: 'accessionNumber', header: 'Accession' },
  { accessorKey: 'nifaProjectNumber', header: 'NIFA project' },
  { accessorKey: 'title', header: 'Title' },
  { accessorKey: 'projectDirector', header: 'PI' },
  { accessorKey: 'aeProjects', header: 'AE projects' },
  amountColumn<AssociatedProject>('Expenses', 'expenses'),
  fteColumn<AssociatedProject>('FTE', 'fte'),
];

export const associatedProjectCsv: CsvColumn<AssociatedProject>[] = [
  { header: 'Accession', key: 'accessionNumber' },
  { header: 'NIFA project', key: 'nifaProjectNumber' },
  { header: 'Title', key: 'title' },
  { header: 'PI', key: 'projectDirector' },
  { header: 'AE projects', key: 'aeProjects' },
  { format: 'currency', header: 'Expenses', key: 'expenses' },
  { header: 'FTE', key: 'fte' },
];

export const unassociatedColumns: ColumnDef<UnassociatedExpense>[] = [
  { accessorKey: 'source', header: 'Source' },
  { accessorKey: 'project', header: 'AE project' },
  { accessorKey: 'fund', header: 'Fund' },
  { accessorKey: 'financialDepartment', header: 'Financial dept' },
  { accessorKey: 'orgR', header: 'OrgR' },
  { accessorKey: 'employeeId', header: 'Employee ID' },
  { accessorKey: 'employeeName', header: 'Employee' },
  { accessorKey: 'expenseSfn', header: 'SFN' },
  amountColumn<UnassociatedExpense>('Expenses', 'expenses'),
  fteColumn<UnassociatedExpense>('FTE', 'fte'),
  { accessorKey: 'reason', header: 'Reason' },
];

export const unassociatedCsv: CsvColumn<UnassociatedExpense>[] = [
  { header: 'Source', key: 'source' },
  { header: 'AE project', key: 'project' },
  { header: 'Fund', key: 'fund' },
  { header: 'Financial dept', key: 'financialDepartment' },
  { header: 'OrgR', key: 'orgR' },
  { header: 'Employee ID', key: 'employeeId' },
  { header: 'Employee', key: 'employeeName' },
  { header: 'SFN', key: 'expenseSfn' },
  { format: 'currency', header: 'Expenses', key: 'expenses' },
  { header: 'FTE', key: 'fte' },
  { header: 'Reason', key: 'reason' },
];

export function ReportSection<T extends object>({
  columns,
  csv,
  data,
  filename,
  title,
}: {
  columns: ColumnDef<T>[];
  csv: CsvColumn<T>[];
  data: T[];
  filename: string;
  title: string;
}) {
  return (
    <section className="space-y-2">
      <h3 className="text-lg font-semibold">{title}</h3>
      <DataTable
        columns={columns}
        data={data}
        initialState={{ pagination: { pageSize: 25 } }}
        tableActions={<ExportDataButton columns={csv} data={data} filename={filename} label="Export" />}
      />
    </section>
  );
}

export function LoadState({ error, isError, isLoading, label }: {
  error: unknown;
  isError: boolean;
  isLoading: boolean;
  label: string;
}) {
  if (isLoading) {
    return <p role="status">Loading {label}...</p>;
  }
  if (isError) {
    return (
      <div className="alert alert-error" role="alert">
        <span>{apiErrorMessage(error, `Could not load ${label}.`)}</span>
      </div>
    );
  }
  return null;
}
