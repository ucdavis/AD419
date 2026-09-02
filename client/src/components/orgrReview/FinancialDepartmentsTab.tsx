import { useState } from 'react';
import { OrgRSelect } from './OrgRSelect.tsx';
import { unmappedFirst } from './orgrTabs.ts';
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

// Levels A and B are always the campus; the college and below are what
// distinguish departments.
const FIRST_SHOWN_LEVEL = 'C';

function shownLevels(row: OrgRFinancialDepartment) {
  return row.hierarchy.filter((level) => level.level >= FIRST_SHOWN_LEVEL);
}

function hierarchyNames(row: OrgRFinancialDepartment): string {
  return shownLevels(row)
    .map((level) => level.name ?? level.code)
    .join(' / ');
}

export function FinancialDepartmentsTab() {
  const { data: rows = [], isLoading } = useQuery(orgRFinancialDepartmentsQueryOptions());
  const { data: orgRs = [] } = useQuery(orgRsQueryOptions());
  const setOrgR = useSetFinancialDepartmentOrgR();
  const [error, setError] = useState<string | null>(null);

  // Freeze the default row order: unmapped rows on top, otherwise by code.
  // Recomputed only when a code appears that the frozen order does not know
  // about yet (a newly seeded row), so mapping a row in place does not
  // immediately move it.
  const [order, setOrder] = useState<string[]>(() =>
    unmappedFirst(rows, (row) => row.financialDepartment).map(
      (row) => row.financialDepartment
    )
  );
  const hasNewCode = rows.some((row) => !order.includes(row.financialDepartment));
  if (hasNewCode) {
    setOrder(
      unmappedFirst(rows, (row) => row.financialDepartment).map(
        (row) => row.financialDepartment
      )
    );
  }

  if (isLoading) {
    return <p role="status">Loading financial departments...</p>;
  }

  const orderIndex = new Map(order.map((code, index) => [code, index]));
  const visible = [...rows].sort(
    (a, b) =>
      (orderIndex.get(a.financialDepartment) ?? Number.MAX_SAFE_INTEGER) -
      (orderIndex.get(b.financialDepartment) ?? Number.MAX_SAFE_INTEGER)
  );

  const columns: ColumnDef<OrgRFinancialDepartment>[] = [
    { accessorKey: 'financialDepartment', header: 'Department' },
    { accessorKey: 'description', header: 'Name' },
    {
      accessorFn: hierarchyNames,
      cell: ({ row }) => {
        const levels = shownLevels(row.original);
        if (levels.length === 0) {
          return <span className="text-base-content/40">—</span>;
        }
        return (
          <span
            className="tooltip tooltip-right cursor-help"
            data-tip={levels.map((level) => level.code).join(' / ')}
          >
            {hierarchyNames(row.original)}
          </span>
        );
      },
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

  const exportRows = visible.map((row) => ({
    description: row.description,
    financialDepartment: row.financialDepartment,
    hierarchy: hierarchyNames(row),
    orgR: row.orgR,
  }));

  return (
    <div className="space-y-4">
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
        tableActions={
          <ExportDataButton
            columns={[
              { header: 'Department', key: 'financialDepartment' },
              { header: 'Name', key: 'description' },
              { header: 'Hierarchy', key: 'hierarchy' },
              { header: 'OrgR', key: 'orgR' },
            ]}
            data={exportRows}
            filename="ad419-orgr-financial-departments.csv"
            label="Export"
          />
        }
      />
    </div>
  );
}
