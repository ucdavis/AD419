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

export function FinancialDepartmentsTab() {
  const { data: rows = [], isLoading } = useQuery(orgRFinancialDepartmentsQueryOptions());
  const { data: orgRs = [] } = useQuery(orgRsQueryOptions());
  const setOrgR = useSetFinancialDepartmentOrgR();
  const [inCycleOnly, setInCycleOnly] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const scope = inCycleOnly ? 'cycle' : 'all';
  const scopedRows = inCycleOnly
    ? rows.filter((row) => row.inCycle || row.orgR === null)
    : rows;

  // Freeze the default row order per scope: unmapped rows on top, otherwise by
  // code. Recomputed only when the in-cycle toggle changes or a code appears
  // that the frozen order does not know about yet (a newly seeded row), so
  // mapping a row in place does not immediately move it.
  const [order, setOrder] = useState<{ codes: string[]; scope: string }>(() => ({
    codes: unmappedFirst(scopedRows, (row) => row.financialDepartment).map(
      (row) => row.financialDepartment
    ),
    scope,
  }));
  const hasNewCode = scopedRows.some(
    (row) => !order.codes.includes(row.financialDepartment)
  );
  if (order.scope !== scope || hasNewCode) {
    setOrder({
      codes: unmappedFirst(scopedRows, (row) => row.financialDepartment).map(
        (row) => row.financialDepartment
      ),
      scope,
    });
  }

  if (isLoading) {
    return <p role="status">Loading financial departments...</p>;
  }

  const orderIndex = new Map(order.codes.map((code, index) => [code, index]));
  const visible = [...scopedRows].sort(
    (a, b) =>
      (orderIndex.get(a.financialDepartment) ?? Number.MAX_SAFE_INTEGER) -
      (orderIndex.get(b.financialDepartment) ?? Number.MAX_SAFE_INTEGER)
  );

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
        <span className="label-text">Only departments in this cycle (unmapped always shown)</span>
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
