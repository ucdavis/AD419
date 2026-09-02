import { useState } from 'react';
import {
  apiErrorMessage,
  type OrgR,
  orgRsQueryOptions,
  useDeleteOrgR,
  useUpsertOrgR,
} from '@/queries/orgr.ts';
import { ConfirmationDialog } from '@/shared/ConfirmationDialog.tsx';
import { DataTable } from '@/shared/dataTable.tsx';
import { ExportDataButton } from '@/shared/exportDataButton.tsx';
import { useQuery } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';

export function OrgRListTab() {
  const { data: orgRs = [], isLoading } = useQuery(orgRsQueryOptions());
  const upsert = useUpsertOrgR();
  const remove = useDeleteOrgR();
  const [newCode, setNewCode] = useState('');
  const [newDescription, setNewDescription] = useState('');
  const [pendingDelete, setPendingDelete] = useState<OrgR | null>(null);
  const [error, setError] = useState<string | null>(null);

  if (isLoading) {
    return <p role="status">Loading OrgRs...</p>;
  }

  const handleAdd = () => {
    const code = newCode.trim().toUpperCase();
    if (!code) {
      return;
    }
    setError(null);
    upsert.mutate(
      { code, description: newDescription.trim() || null },
      {
        onError: (err) => setError(apiErrorMessage(err, 'Could not add the OrgR.')),
        onSuccess: () => {
          setNewCode('');
          setNewDescription('');
        },
      }
    );
  };

  const handleDescriptionBlur = (orgR: OrgR, description: string) => {
    const trimmed = description.trim() || null;
    if (trimmed === orgR.description) {
      return;
    }
    setError(null);
    upsert.mutate(
      { code: orgR.code, description: trimmed },
      { onError: (err) => setError(apiErrorMessage(err, 'Could not update the OrgR.')) }
    );
  };

  const confirmDelete = () => {
    if (!pendingDelete) {
      return;
    }
    const code = pendingDelete.code;
    setPendingDelete(null);
    setError(null);
    remove.mutate(code, {
      onError: (err) => setError(apiErrorMessage(err, `Could not delete ${code}.`)),
    });
  };

  const columns: ColumnDef<OrgR>[] = [
    { accessorKey: 'code', header: 'OrgR' },
    {
      accessorKey: 'description',
      cell: ({ row }) => (
        <input
          aria-label={`Description for ${row.original.code}`}
          className="input input-bordered input-sm w-full"
          defaultValue={row.original.description ?? ''}
          key={row.original.description ?? ''}
          onBlur={(event) => handleDescriptionBlur(row.original, event.target.value)}
        />
      ),
      header: 'Description',
    },
    { accessorKey: 'referenceCount', header: 'Used by' },
    {
      cell: ({ row }) => (
        <button
          aria-label={`Delete ${row.original.code}`}
          className="btn btn-ghost btn-xs text-error"
          disabled={row.original.referenceCount > 0}
          onClick={() => setPendingDelete(row.original)}
          title={
            row.original.referenceCount > 0
              ? 'Reassign its mappings before deleting.'
              : undefined
          }
          type="button"
        >
          Delete
        </button>
      ),
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
          <span className="label-text">Code</span>
          <input
            aria-label="New OrgR code"
            className="input input-bordered input-sm uppercase"
            maxLength={10}
            onChange={(event) => setNewCode(event.target.value)}
            value={newCode}
          />
        </label>
        <label className="form-control grow">
          <span className="label-text">Description</span>
          <input
            aria-label="New OrgR description"
            className="input input-bordered input-sm w-full"
            maxLength={200}
            onChange={(event) => setNewDescription(event.target.value)}
            value={newDescription}
          />
        </label>
        <button
          className="btn btn-primary btn-sm"
          disabled={!newCode.trim() || upsert.isPending}
          type="submit"
        >
          Add OrgR
        </button>
      </form>

      {error ? (
        <div className="alert alert-error" role="alert">
          <span>{error}</span>
        </div>
      ) : null}

      <DataTable
        columns={columns}
        data={orgRs}
        globalFilter="right"
        initialState={{ pagination: { pageSize: 25 } }}
        tableActions={
          <ExportDataButton
            columns={[
              { header: 'OrgR', key: 'code' },
              { header: 'Description', key: 'description' },
              { header: 'Used by', key: 'referenceCount' },
            ]}
            data={orgRs}
            filename="ad419-orgr-list.csv"
            label="Export"
          />
        }
      />

      <ConfirmationDialog
        confirmClassName="btn-error"
        confirmLabel="Delete"
        onCancel={() => setPendingDelete(null)}
        onConfirm={confirmDelete}
        open={pendingDelete !== null}
        title={`Delete ${pendingDelete?.code ?? ''}?`}
      >
        <p>This removes the OrgR from the list. Mappings that use it block deletion.</p>
      </ConfirmationDialog>
    </div>
  );
}
