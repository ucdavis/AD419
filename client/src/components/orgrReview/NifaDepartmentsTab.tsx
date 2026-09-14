import { useState } from 'react';
import { OrgRSelect } from './OrgRSelect.tsx';
import { unmappedFirst } from './orgrTabs.ts';
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

  // Freeze the default row order: unmapped rows on top, otherwise by code.
  // Recomputed only when a code appears that the frozen order does not know
  // about yet, so mapping a row in place does not immediately move it.
  const [order, setOrder] = useState<string[]>(() =>
    unmappedFirst(rows, (row) => row.nifaDepartment).map(
      (row) => row.nifaDepartment
    )
  );
  const hasNewCode = rows.some((row) => !order.includes(row.nifaDepartment));
  if (hasNewCode) {
    setOrder(
      unmappedFirst(rows, (row) => row.nifaDepartment).map(
        (row) => row.nifaDepartment
      )
    );
  }

  if (isLoading) {
    return <p role="status">Loading NIFA departments...</p>;
  }

  const orderIndex = new Map(order.map((code, index) => [code, index]));
  const ordered = [...rows].sort(
    (a, b) =>
      (orderIndex.get(a.nifaDepartment) ?? Number.MAX_SAFE_INTEGER) -
      (orderIndex.get(b.nifaDepartment) ?? Number.MAX_SAFE_INTEGER)
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
