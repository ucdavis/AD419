import { useState } from 'react';
import { OrgRSelect } from './OrgRSelect.tsx';
import { FilterTypeahead } from '@/components/expenseReview/FilterTypeahead.tsx';
import {
  apiErrorMessage,
  orgRsQueryOptions,
  piAppointmentsQueryOptions,
  pisQueryOptions,
  useAddPiAppointment,
  useRemovePiAppointment,
} from '@/queries/orgr.ts';
import { DataTable } from '@/shared/dataTable.tsx';
import { ExportDataButton } from '@/shared/exportDataButton.tsx';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

// One row per appointment, then one row per PI who has none. additionalOrgR
// and skipped204Count are null on a PI with only their default OrgR.
interface PiRow {
  additionalOrgR: string | null;
  defaultOrgR: string;
  name: string;
  projectCount: number;
  skipped204Count: number | null;
  ucpEmployeeId: string;
}

function projectLabel(count: number): string {
  return count === 1 ? '1 project' : `${count} projects`;
}

export function PiAppointmentsTab() {
  const { data: pis = [], isLoading: pisLoading } = useQuery(pisQueryOptions());
  const { data: appointments = [], isLoading: appointmentsLoading } = useQuery(
    piAppointmentsQueryOptions()
  );
  const { data: orgRs = [] } = useQuery(orgRsQueryOptions());
  const add = useAddPiAppointment();
  const remove = useRemovePiAppointment();
  const [employeeId, setEmployeeId] = useState('');
  // Bumped after a successful add to give the PI search box a fresh, empty state.
  const [piSearchKey, setPiSearchKey] = useState(0);
  const [orgR, setOrgR] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  if (pisLoading || appointmentsLoading) {
    return <p role="status">Loading PI appointments...</p>;
  }

  const handleAdd = () => {
    if (!employeeId || !orgR) {
      return;
    }
    setError(null);
    add.mutate(
      { orgR, ucpEmployeeId: employeeId },
      {
        onError: (err) => setError(apiErrorMessage(err, 'Could not add the appointment.')),
        onSuccess: () => {
          setEmployeeId('');
          setOrgR(null);
          setPiSearchKey((key) => key + 1);
        },
      }
    );
  };

  // PIs with an additional OrgR lead the list; everyone else follows with
  // only their default OrgR. Both lists arrive sorted by name.
  const appointed = new Set(appointments.map((appointment) => appointment.ucpEmployeeId));
  const rows: PiRow[] = [
    ...appointments.map((appointment) => ({
      additionalOrgR: appointment.orgR,
      defaultOrgR: appointment.homeOrgRs.join(', '),
      name: appointment.name,
      projectCount: appointment.projectCount,
      skipped204Count: appointment.skipped204Count,
      ucpEmployeeId: appointment.ucpEmployeeId,
    })),
    ...pis
      .filter((pi) => !appointed.has(pi.ucpEmployeeId))
      .map((pi) => ({
        additionalOrgR: null,
        defaultOrgR: pi.homeOrgRs.join(', '),
        name: pi.name,
        projectCount: pi.projectCount,
        skipped204Count: null,
        ucpEmployeeId: pi.ucpEmployeeId,
      })),
  ];

  // The employee ID is part of what the search matches, so either works.
  const piOptions = pis.map((pi) => ({
    label: `${pi.name} (${projectLabel(pi.projectCount)})`,
    value: pi.ucpEmployeeId,
  }));

  const columns: ColumnDef<PiRow>[] = [
    { accessorKey: 'name', header: 'PI' },
    { accessorKey: 'ucpEmployeeId', header: 'Employee ID' },
    { accessorKey: 'defaultOrgR', header: 'Default OrgR' },
    { accessorKey: 'additionalOrgR', header: 'Additional OrgR' },
    { accessorKey: 'projectCount', header: 'Projects' },
    { accessorKey: 'skipped204Count', header: '204 Projects Skipped' },
    {
      cell: ({ row }) => {
        const { additionalOrgR, name, ucpEmployeeId } = row.original;
        if (additionalOrgR === null) {
          return null;
        }
        return (
          <button
            aria-label={`Remove ${name} from ${additionalOrgR}`}
            className="btn btn-ghost btn-xs text-error"
            disabled={remove.isPending}
            onClick={() => {
              setError(null);
              remove.mutate(
                { orgR: additionalOrgR, ucpEmployeeId },
                { onError: (err) => setError(apiErrorMessage(err, 'Could not remove the appointment.')) }
              );
            }}
            type="button"
          >
            Remove
          </button>
        );
      },
      header: '',
      id: 'actions',
    },
  ];

  return (
    <div className="space-y-4">
      <form
        className="flex flex-wrap items-end gap-2"
        onSubmit={(event) => {
          event.preventDefault();
          handleAdd();
        }}
      >
        <div className="w-80">
          <FilterTypeahead
            ariaLabel="PI"
            disabled={false}
            keepChoice
            key={piSearchKey}
            label="PI"
            onAdd={setEmployeeId}
            onEdit={() => setEmployeeId('')}
            options={piOptions}
            placeholder="Type a name to search"
            selected={[]}
          />
        </div>
        <label className="form-control">
          <span className="label-text">Additional OrgR</span>
          <OrgRSelect ariaLabel="OrgR to add" onChange={setOrgR} orgRs={orgRs} value={orgR} />
        </label>
        <button
          className="btn btn-primary btn-sm"
          disabled={!employeeId || !orgR || add.isPending}
          type="submit"
        >
          Add appointment
        </button>
      </form>

      {error ? (
        <div className="alert alert-error" role="alert">
          <span>{error}</span>
        </div>
      ) : null}

      <section aria-label="PI appointments">
        <DataTable
          columns={columns}
          data={rows}
          filterPlaceholder="Search by PI or OrgR..."
          globalFilter="right"
          initialState={{ pagination: { pageSize: 25 } }}
          tableActions={
            <ExportDataButton
              columns={[
                { header: 'PI', key: 'name' },
                { header: 'Employee ID', key: 'ucpEmployeeId' },
                { header: 'Default OrgR', key: 'defaultOrgR' },
                { header: 'Additional OrgR', key: 'additionalOrgR' },
                { header: 'Projects', key: 'projectCount' },
                { header: '204 Projects Skipped', key: 'skipped204Count' },
              ]}
              data={rows}
              filename="ad419-pi-appointments.csv"
              label="Export"
            />
          }
        />
      </section>
    </div>
  );
}
