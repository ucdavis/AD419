import {
  associatedProjectColumns,
  associatedProjectCsv,
  LoadState,
  ReportSection,
  unassociatedColumns,
  unassociatedCsv,
} from './reportTables.tsx';
import { rule220ReportQueryOptions } from '@/queries/autoAssociations.ts';
import { useQuery } from '@tanstack/react-query';

export function Rule220Tab() {
  const { data, error, isError, isLoading } = useQuery(rule220ReportQueryOptions());
  if (isLoading || isError || !data) {
    return <LoadState error={error} isError={isError} isLoading={isLoading} label="the 220 report" />;
  }
  return (
    <div className="space-y-6">
      <ReportSection
        columns={associatedProjectColumns}
        csv={associatedProjectCsv}
        data={data.projects}
        filename="auto-associations-220.csv"
        title="Associated 220 projects"
      />
      <ReportSection
        columns={unassociatedColumns}
        csv={unassociatedCsv}
        data={data.unassociated}
        filename="auto-associations-220-unassociated.csv"
        title="Not associated"
      />
    </div>
  );
}
