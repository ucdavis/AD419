import { useState } from 'react';
import {
  formatCurrency,
  formatFte,
} from '@/components/autoAssociations/autoAssociationsTabs.ts';
import type { CsvColumn } from '@/lib/csv.ts';
import type {
  JobCodeClassification,
  JobCodeClassifications,
  StaffTypeOption,
} from '@/queries/jobCodeClassifications.ts';
import { DataTable } from '@/shared/dataTable.tsx';
import { ExportDataButton } from '@/shared/exportDataButton.tsx';
import type { ColumnDef } from '@tanstack/react-table';

const numeric = { cellClassName: 'text-right tabular-nums', headerClassName: 'text-right' };

const jobCodeCsv: CsvColumn<JobCodeClassification>[] = [
  { header: 'Job code', key: 'jobCode' },
  { header: 'Title', key: 'titleName' },
  { header: 'Staff type', key: 'staffTypeCode' },
  { header: 'Job SFN', key: 'fteSfn' },
  { header: 'Employees', key: 'employeeCount' },
  { format: 'currency', header: 'Amount', key: 'amount' },
  { header: 'FTE', key: 'fte' },
];

function optionLabel(option: StaffTypeOption): string {
  return `${option.fteSfn} ${option.description ?? ''}`.trim();
}

function JobSfnSelect({
  onAssign,
  row,
  saving,
  staffTypes,
}: {
  onAssign: (jobCode: string, staffTypeCode: string) => void;
  row: JobCodeClassification;
  saving: boolean;
  staffTypes: StaffTypeOption[];
}) {
  // A staff type that is not offered (no line, or no longer in the list)
  // leaves the row unassigned, so it shows the placeholder.
  const offered = staffTypes.some((option) => option.staffTypeCode === row.staffTypeCode);
  const value = offered ? (row.staffTypeCode ?? '') : '';

  return (
    <select
      aria-label={`Job SFN for ${row.jobCode}`}
      className="select select-xs select-bordered"
      // Each pick is its own request. Locked while one is running so a
      // second pick cannot finish first and then be overwritten by it.
      disabled={saving}
      onChange={(event) => {
        if (event.target.value !== '') {
          onAssign(row.jobCode, event.target.value);
        }
      }}
      value={value}
    >
      {/* Disabled so an assignment can be changed but not cleared. */}
      <option disabled value="">
        Select...
      </option>
      {staffTypes.map((option) => (
        <option key={option.staffTypeCode} value={option.staffTypeCode}>
          {optionLabel(option)}
        </option>
      ))}
    </select>
  );
}

export function JobCodeTab({
  data,
  onAssign,
  savingJobCodes = [],
}: {
  data: JobCodeClassifications;
  onAssign: (jobCode: string, staffTypeCode: string) => void;
  savingJobCodes?: string[];
}) {
  // Freeze the server's order (codes that need a line first) when the tab is
  // entered, so assigning a row in place does not move it. Codes that show up
  // later go to the end. Column sorting overrides this when a header is clicked.
  const [order] = useState(() => data.rows.map((row) => row.jobCode));
  const orderIndex = new Map(order.map((code, index) => [code, index]));
  const rows = [...data.rows].sort(
    (a, b) =>
      (orderIndex.get(a.jobCode) ?? order.length) - (orderIndex.get(b.jobCode) ?? order.length)
  );

  const columns: ColumnDef<JobCodeClassification>[] = [
    { accessorKey: 'jobCode', header: 'Job code' },
    { accessorKey: 'titleName', header: 'Title' },
    {
      accessorFn: (row) => row.fteSfn ?? '',
      cell: ({ row }) => (
        <JobSfnSelect
          onAssign={onAssign}
          row={row.original}
          saving={savingJobCodes.includes(row.original.jobCode)}
          staffTypes={data.staffTypes}
        />
      ),
      header: 'Job SFN',
      id: 'fteSfn',
    },
    { accessorKey: 'employeeCount', header: 'Employees', meta: numeric },
    {
      accessorKey: 'amount',
      cell: ({ getValue }) => formatCurrency(getValue<number>()),
      header: 'Amount',
      meta: numeric,
    },
    {
      accessorKey: 'fte',
      cell: ({ getValue }) => formatFte(getValue<number>()),
      header: 'FTE',
      meta: numeric,
    },
  ];

  return (
    <DataTable
      columns={columns}
      data={rows}
      globalFilter="right"
      initialState={{ pagination: { pageSize: 25 } }}
      tableActions={
        <ExportDataButton
          columns={jobCodeCsv}
          data={rows}
          filename="data-classification-job-codes.csv"
          label="Export"
        />
      }
    />
  );
}
