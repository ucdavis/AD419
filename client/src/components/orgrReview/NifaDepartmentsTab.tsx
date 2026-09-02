import { useState } from 'react';
import { OrgRSelect } from './OrgRSelect.tsx';
import {
  apiErrorMessage,
  type OrgRNifaDepartment,
  orgRNifaDepartmentsQueryOptions,
  orgRsQueryOptions,
  useSetNifaDepartmentOrgR,
} from '@/queries/orgr.ts';
import { DataTable } from '@/shared/dataTable.tsx';
import { ExportDataButton } from '@/shared/exportDataButton.tsx';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

export function NifaDepartmentsTab() {
  const { data: rows = [], isLoading } = useQuery(orgRNifaDepartmentsQueryOptions());
  const { data: orgRs = [] } = useQuery(orgRsQueryOptions());
  const setOrgR = useSetNifaDepartmentOrgR();
  const [error, setError] = useState<string | null>(null);

  if (isLoading) {
    return <p>Loading NIFA departments...</p>;
  }

  const ordered = [...rows].sort(
    (a, b) =>
      (a.orgR === null ? 0 : 1) - (b.orgR === null ? 0 : 1) ||
      a.nifaDepartment.localeCompare(b.nifaDepartment)
  );

  const columns: ColumnDef<OrgRNifaDepartment>[] = [
    { accessorKey: 'nifaDepartment', header: 'NIFA Department' },
    { accessorKey: 'projectCount', header: 'Projects' },
    {
      accessorFn: (row) => row.orgR ?? '',
      cell: ({ row }) => (
        <OrgRSelect
          ariaLabel={`OrgR for ${row.original.nifaDepartment}`}
          onChange={(orgR) => {
            setError(null);
            setOrgR.mutate(
              { nifaDepartment: row.original.nifaDepartment, orgR },
              { onError: (err) => setError(apiErrorMessage(err, 'Could not save the OrgR.')) }
            );
          }}
          orgRs={orgRs}
          value={row.original.orgR}
        />
      ),
      header: 'OrgR',
      id: 'orgR',
    },
  ];

  return (
    <div className="space-y-4">
      {error ? (
        <div className="alert alert-error" role="alert">
          <span>{error}</span>
        </div>
      ) : null}
      <DataTable
        columns={columns}
        data={ordered}
        globalFilter="right"
        initialState={{ pagination: { pageSize: 25 } }}
        tableActions={
          <ExportDataButton
            columns={[
              { header: 'NIFA Department', key: 'nifaDepartment' },
              { header: 'Projects', key: 'projectCount' },
              { header: 'OrgR', key: 'orgR' },
            ]}
            data={ordered}
            filename="ad419-orgr-nifa-departments.csv"
            label="Export"
          />
        }
      />
    </div>
  );
}
