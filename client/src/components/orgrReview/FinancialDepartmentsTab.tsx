import { useState } from 'react';
import { OrgRSelect } from './OrgRSelect.tsx';
import {
  apiErrorMessage,
  type OrgRFinancialDepartment,
  orgRFinancialDepartmentsQueryOptions,
  orgRsQueryOptions,
  useSetFinancialDepartmentOrgR,
} from '@/queries/orgr.ts';
import { DataTable } from '@/shared/dataTable.tsx';
import { ExportDataButton } from '@/shared/exportDataButton.tsx';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

// Unmapped rows first, otherwise stable by code.
function unmappedFirst(rows: OrgRFinancialDepartment[]): OrgRFinancialDepartment[] {
  return [...rows].sort(
    (a, b) =>
      (a.orgR === null ? 0 : 1) - (b.orgR === null ? 0 : 1) ||
      a.financialDepartment.localeCompare(b.financialDepartment)
  );
}

export function FinancialDepartmentsTab() {
  const { data: rows = [], isLoading } = useQuery(orgRFinancialDepartmentsQueryOptions());
  const { data: orgRs = [] } = useQuery(orgRsQueryOptions());
  const setOrgR = useSetFinancialDepartmentOrgR();
  const [inCycleOnly, setInCycleOnly] = useState(true);
  const [error, setError] = useState<string | null>(null);

  if (isLoading) {
    return <p>Loading financial departments...</p>;
  }

  const visible = unmappedFirst(inCycleOnly ? rows.filter((row) => row.inCycle) : rows);

  const columns: ColumnDef<OrgRFinancialDepartment>[] = [
    { accessorKey: 'financialDepartment', header: 'Department' },
    { accessorKey: 'description', header: 'Name' },
    {
      accessorFn: (row) => row.hierarchy.map((level) => level.code).join(' / '),
      cell: ({ row }) =>
        row.original.hierarchy.length === 0 ? (
          <span className="text-base-content/40">—</span>
        ) : (
          <span
            className="tooltip tooltip-right underline decoration-dotted cursor-help"
            data-tip={row.original.hierarchy.map((level) => level.name ?? level.code).join(' / ')}
          >
            {row.original.hierarchy.map((level) => level.code).join(' / ')}
          </span>
        ),
      header: 'Hierarchy',
      id: 'hierarchy',
    },
    {
      accessorFn: (row) => row.orgR ?? '',
      cell: ({ row }) => (
        <OrgRSelect
          ariaLabel={`OrgR for ${row.original.financialDepartment}`}
          onChange={(orgR) => {
            setError(null);
            setOrgR.mutate(
              { financialDepartment: row.original.financialDepartment, orgR },
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
      <label className="label cursor-pointer justify-start gap-2">
        <input
          aria-label="Only departments in this cycle"
          checked={inCycleOnly}
          className="checkbox checkbox-sm"
          onChange={(event) => setInCycleOnly(event.target.checked)}
          type="checkbox"
        />
        <span className="label-text">Only departments in this cycle</span>
      </label>

      {error ? (
        <div className="alert alert-error" role="alert">
          <span>{error}</span>
        </div>
      ) : null}

      <DataTable
        columns={columns}
        data={visible}
        globalFilter="right"
        initialState={{ pagination: { pageSize: 25 } }}
        key={inCycleOnly ? 'cycle' : 'all'}
        tableActions={
          <ExportDataButton
            columns={[
              { header: 'Department', key: 'financialDepartment' },
              { header: 'Name', key: 'description' },
              { header: 'OrgR', key: 'orgR' },
              { header: 'In cycle', key: 'inCycle' },
            ]}
            data={visible}
            filename="ad419-orgr-financial-departments.csv"
            label="Export"
          />
        }
      />
    </div>
  );
}
