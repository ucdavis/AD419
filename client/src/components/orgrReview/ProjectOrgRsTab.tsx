import { useState } from 'react';
import { OrgRSelect } from './OrgRSelect.tsx';
import {
  apiErrorMessage,
  orgRsQueryOptions,
  type ProjectOrgR,
  projectOrgRsQueryOptions,
  useAddProjectOrgR,
  useRemoveProjectOrgR,
} from '@/queries/orgr.ts';
import { DataTable } from '@/shared/dataTable.tsx';
import { ExportDataButton } from '@/shared/exportDataButton.tsx';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

export function ProjectOrgRsTab() {
  const { data: rows = [], isLoading } = useQuery(projectOrgRsQueryOptions());
  const { data: orgRs = [] } = useQuery(orgRsQueryOptions());
  const add = useAddProjectOrgR();
  const remove = useRemoveProjectOrgR();
  const [accession, setAccession] = useState('');
  const [orgR, setOrgR] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  if (isLoading) {
    return <p>Loading project OrgRs...</p>;
  }

  const handleAdd = () => {
    const accessionNumber = accession.trim();
    if (!accessionNumber || !orgR) {
      return;
    }
    setError(null);
    add.mutate(
      { accessionNumber, orgR },
      {
        onError: (err) => setError(apiErrorMessage(err, 'Could not add the project.')),
        onSuccess: () => {
          setAccession('');
          setOrgR(null);
        },
      }
    );
  };

  const columns: ColumnDef<ProjectOrgR>[] = [
    { accessorKey: 'accessionNumber', header: 'Accession' },
    { accessorKey: 'nifaProjectNumber', header: 'NIFA Project' },
    { accessorKey: 'title', header: 'Title' },
    { accessorKey: 'projectDirector', header: 'Director' },
    { accessorKey: 'orgR', header: 'OrgR' },
    {
      accessorKey: 'source',
      cell: ({ row }) => (
        <span className={`badge badge-sm ${row.original.source === 'Manual' ? 'badge-info' : 'badge-ghost'}`}>
          {row.original.source}
        </span>
      ),
      header: 'Source',
    },
    {
      cell: ({ row }) =>
        row.original.source === 'Manual' ? (
          <button
            aria-label={`Remove ${row.original.accessionNumber} from ${row.original.orgR}`}
            className="btn btn-ghost btn-xs text-error"
            onClick={() => {
              setError(null);
              remove.mutate(
                { accessionNumber: row.original.accessionNumber, orgR: row.original.orgR },
                { onError: (err) => setError(apiErrorMessage(err, 'Could not remove the project.')) }
              );
            }}
            type="button"
          >
            Remove
          </button>
        ) : null,
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
        <label className="form-control">
          <span className="label-text">Accession number</span>
          <input
            aria-label="Accession number"
            className="input input-bordered input-sm"
            maxLength={7}
            onChange={(event) => setAccession(event.target.value)}
            value={accession}
          />
        </label>
        <label className="form-control">
          <span className="label-text">OrgR</span>
          <OrgRSelect ariaLabel="OrgR to add" onChange={setOrgR} orgRs={orgRs} value={orgR} />
        </label>
        <button
          className="btn btn-primary btn-sm"
          disabled={!accession.trim() || !orgR || add.isPending}
          type="submit"
        >
          Add to OrgR
        </button>
      </form>

      {error ? (
        <div className="alert alert-error" role="alert">
          <span>{error}</span>
        </div>
      ) : null}

      <DataTable
        columns={columns}
        data={rows}
        filterPlaceholder="Search by accession, project number, title..."
        globalFilter="right"
        initialState={{ pagination: { pageSize: 25 } }}
        tableActions={
          <ExportDataButton
            columns={[
              { header: 'Accession', key: 'accessionNumber' },
              { header: 'NIFA Project', key: 'nifaProjectNumber' },
              { header: 'Title', key: 'title' },
              { header: 'Director', key: 'projectDirector' },
              { header: 'OrgR', key: 'orgR' },
              { header: 'Source', key: 'source' },
            ]}
            data={rows}
            filename="ad419-orgr-projects.csv"
            label="Export"
          />
        }
      />
    </div>
  );
}
