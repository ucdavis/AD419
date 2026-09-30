import { amountColumn, LoadState, ReportSection } from './reportTables.tsx';
import type { CsvColumn } from '@/lib/csv.ts';
import { type ExcludedProject, excludedProjectsQueryOptions } from '@/queries/autoAssociations.ts';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

const excludedProjectColumns: ColumnDef<ExcludedProject>[] = [
  { accessorKey: 'accessionNumber', header: 'Accession' },
  { accessorKey: 'nifaProjectNumber', header: 'NIFA project' },
  { accessorKey: 'title', header: 'Title' },
  { accessorKey: 'projectDirector', header: 'PI' },
  { accessorKey: 'aeProjects', header: 'AE projects' },
  amountColumn<ExcludedProject>('Direct expenses', 'total'),
];

const excludedProjectCsv: CsvColumn<ExcludedProject>[] = [
  { header: 'Accession', key: 'accessionNumber' },
  { header: 'NIFA project', key: 'nifaProjectNumber' },
  { header: 'Title', key: 'title' },
  { header: 'PI', key: 'projectDirector' },
  { header: 'AE projects', key: 'aeProjects' },
  { format: 'currency', header: 'Direct expenses', key: 'total' },
];

export function ExcludedProjectsTab() {
  const { data, error, isError, isLoading } = useQuery(excludedProjectsQueryOptions());
  if (isLoading || isError || !data) {
    return <LoadState error={error} isError={isError} isLoading={isLoading} label="the excluded projects report" />;
  }
  return (
    <div className="space-y-6">
      <ReportSection
        columns={excludedProjectColumns}
        csv={excludedProjectCsv}
        data={data}
        filename="auto-associations-under-100.csv"
        title="Projects under $100"
      />
    </div>
  );
}
