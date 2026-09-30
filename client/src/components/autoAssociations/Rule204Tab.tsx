import {
  associatedProjectColumns,
  associatedProjectCsv,
  LoadState,
  ReportSection,
  unassociatedColumns,
  unassociatedCsv,
} from './reportTables.tsx';
import { rule204ReportQueryOptions } from '@/queries/autoAssociations.ts';
import { useQuery } from '@tanstack/react-query';

export function Rule204Tab() {
  const { data, error, isError, isLoading } = useQuery(rule204ReportQueryOptions());
  if (isLoading || isError || !data) {
    return <LoadState error={error} isError={isError} isLoading={isLoading} label="the 204 report" />;
  }
  return (
    <div className="space-y-6">
      <ReportSection
        columns={associatedProjectColumns}
        csv={associatedProjectCsv}
        data={data.projects}
        filename="auto-associations-204.csv"
        title="Associated 204 projects"
      />
      <ReportSection
        columns={unassociatedColumns}
        csv={unassociatedCsv}
        data={data.unassociated}
        filename="auto-associations-204-unassociated.csv"
        title="Not associated"
      />
      <ReportSection
        columns={unassociatedColumns}
        csv={unassociatedCsv}
        data={data.misclassified}
        filename="auto-associations-204-misclassified.csv"
        title="Misclassified 204 expenses (read only)"
      />
    </div>
  );
}
