import { downloadExcelCsv, toExcelCsv } from '@/lib/csv.ts';
import { fetchJson, HttpError } from '@/lib/api.ts';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';
import { useState } from 'react';
import { DataTable } from '@/shared/dataTable.tsx';

type ImportDatasetId =
  | 'active-projects'
  | 'all-projects'
  | 'assistance-listing-numbers';

interface ImportDatasetOption {
  id: ImportDatasetId;
  label: string;
}

interface ImportCellError {
  code: string;
  message: string;
  rawValue?: string | null;
  sourceHeader?: string | null;
  targetColumn: string;
}

interface ImportFileError {
  code: string;
  message: string;
  sourceHeader?: string | null;
  targetColumn?: string | null;
}

interface ImportRowResult {
  cellErrors: ImportCellError[];
  errors: string[];
  rowNum: number;
  values: Record<string, string | null>;
}

interface ImportValidationResponse {
  attemptedRows: number;
  dataset: string;
  fileErrors: ImportFileError[];
  filename?: string | null;
  importLogId?: number | null;
  rows: ImportRowResult[];
  succeeded: false;
}

interface ImportSuccessResponse {
  dataset: string;
  filename: string;
  importedAt: string;
  importLogId?: number | null;
  rowsImported: number;
  succeeded: true;
}

type ImportResponse = ImportSuccessResponse | ImportValidationResponse;

interface RecentImportResponse {
  attemptedRows: number;
  dataset: string;
  filename: string;
  id: number;
  importedAt: string;
  rowsImported?: number | null;
  status: string;
  uploadedByEmail?: string | null;
  uploadedByName?: string | null;
}

interface ImportDatasetSummaryResponse {
  dataset: ImportDatasetId;
  displayName: string;
  lastImport?: RecentImportResponse | null;
}

const datasetOptions: ImportDatasetOption[] = [
  { id: 'all-projects', label: 'All Projects' },
  { id: 'active-projects', label: 'Active Projects' },
  {
    id: 'assistance-listing-numbers',
    label: 'Assistance Listing Numbers',
  },
];

async function uploadImport({
  dataset,
  file,
}: {
  dataset: ImportDatasetId;
  file: File;
}): Promise<ImportSuccessResponse> {
  const formData = new FormData();
  formData.append('file', file);

  const res = await fetch(`/api/imports/${dataset}`, {
    body: formData,
    credentials: 'same-origin',
    headers: {
      Accept: 'application/json',
    },
    method: 'POST',
  });
  const text = await res.text();
  const contentType = res.headers.get('content-type') ?? '';
  const data =
    contentType.includes('application/json') && text
      ? (JSON.parse(text) as ImportResponse)
      : text;

  if (res.status === 401) {
    window.location.href = `/login?returnUrl=${encodeURIComponent(
      window.location.pathname + window.location.search
    )}`;
    return new Promise<ImportSuccessResponse>(() => {});
  }

  if (!res.ok) {
    throw new HttpError(res.status, `/api/imports/${dataset}`, data);
  }

  return data as ImportSuccessResponse;
}

async function fetchRecentImports(): Promise<ImportDatasetSummaryResponse[]> {
  return fetchJson<ImportDatasetSummaryResponse[]>('/api/imports/recent');
}

export function FlatFileImportPanel() {
  const queryClient = useQueryClient();
  const [dataset, setDataset] = useState<ImportDatasetId>('all-projects');
  const [file, setFile] = useState<File | null>(null);
  const [validation, setValidation] = useState<ImportValidationResponse | null>(
    null
  );
  const [success, setSuccess] = useState<ImportSuccessResponse | null>(null);
  const recentImportsQuery = useQuery({
    queryFn: fetchRecentImports,
    queryKey: ['imports', 'recent'],
  });
  const selectedRecentImport = recentImportsQuery.data?.find(
    (summary) => summary.dataset === dataset
  )?.lastImport;

  const mutation = useMutation({
    mutationFn: uploadImport,
    onError: (error) => {
      setSuccess(null);
      if (error instanceof HttpError && isValidationResponse(error.body)) {
        setValidation(error.body);
        void queryClient.invalidateQueries({ queryKey: ['imports', 'recent'] });
        return;
      }

      setValidation({
        attemptedRows: 0,
        dataset,
        fileErrors: [
          {
            code: 'upload_failed',
            message: 'The import could not be completed.',
          },
        ],
        filename: file?.name,
        rows: [],
        succeeded: false,
      });
    },
    onSuccess: async (response) => {
      setValidation(null);
      setSuccess(response);
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['ad419Workflow'] }),
        queryClient.invalidateQueries({ queryKey: ['imports', 'recent'] }),
      ]);
    },
  });

  const canUpload = Boolean(file) && !mutation.isPending;

  return (
    <div className="space-y-5">
      <div className="grid gap-4 lg:grid-cols-[minmax(12rem,18rem)_1fr_auto] lg:items-end">
        <label className="form-control w-full">
          <span className="label-text">Dataset</span>
          <select
            className="select select-bordered w-full"
            onChange={(event) => {
              setDataset(event.target.value as ImportDatasetId);
              setValidation(null);
              setSuccess(null);
            }}
            value={dataset}
          >
            {datasetOptions.map((option) => (
              <option key={option.id} value={option.id}>
                {option.label}
              </option>
            ))}
          </select>
        </label>

        <label className="form-control w-full">
          <span className="label-text">Import file</span>
          <input
            accept=".csv,.xlsx"
            className="file-input file-input-bordered w-full"
            onChange={(event) => {
              setFile(event.target.files?.[0] ?? null);
              setValidation(null);
              setSuccess(null);
            }}
            type="file"
          />
        </label>

        <button
          className="btn btn-primary"
          disabled={!canUpload}
          onClick={() => {
            if (file) {
              mutation.mutate({ dataset, file });
            }
          }}
          type="button"
        >
          {mutation.isPending ? 'Importing' : 'Upload'}
        </button>
      </div>

      {selectedRecentImport && (
        <RecentImportSummary importLog={selectedRecentImport} />
      )}

      {success && (
        <div className="alert alert-success">
          <span>
            Imported {success.rowsImported.toLocaleString()} rows from{' '}
            {success.filename}.
          </span>
        </div>
      )}

      {validation && <ValidationResults validation={validation} />}
    </div>
  );
}

function RecentImportSummary({
  importLog,
}: {
  importLog: RecentImportResponse;
}) {
  const succeeded = importLog.status === 'Succeeded';
  const rowCount = succeeded
    ? (importLog.rowsImported ?? 0)
    : importLog.attemptedRows;

  return (
    <div className="flex flex-col gap-2 rounded-box border border-base-300 bg-base-100 p-4 text-sm sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-2">
          <span
            className={`badge ${succeeded ? 'badge-success' : 'badge-error'}`}
          >
            {succeeded ? 'Succeeded' : 'Failed'}
          </span>
          <span className="font-medium">Last import attempt</span>
        </div>
        <p
          className="mt-1 truncate text-base-content/70"
          title={importLog.filename}
        >
          {importLog.filename}
        </p>
      </div>
      <div className="shrink-0 text-base-content/70 sm:text-right">
        <div>{rowCount.toLocaleString()} rows</div>
        <time dateTime={importLog.importedAt}>
          {formatImportDate(importLog.importedAt)}
        </time>
      </div>
    </div>
  );
}

function ValidationResults({
  validation,
}: {
  validation: ImportValidationResponse;
}) {
  const rows = validation.rows;
  const failedRows = rows.filter(rowHasErrors).length;
  const valueColumns = Array.from(
    new Set(rows.flatMap((row) => Object.keys(row.values)))
  ).sort();
  const columnsWithErrors = new Set(
    rows.flatMap((row) => row.cellErrors.map((error) => error.targetColumn))
  );

  const columns: ColumnDef<ImportRowResult>[] = [
    {
      accessorKey: 'rowNum',
      cell: ({ row }) => (
        <span
          className={
            rowHasErrors(row.original)
              ? 'block min-w-10 rounded bg-error/15 px-2 py-1 text-center text-error'
              : 'block min-w-10 px-2 py-1 text-center'
          }
        >
          {row.original.rowNum}
        </span>
      ),
      header: 'Row',
      meta: {
        cellClassName: 'h-12 w-20 min-w-20 align-middle',
        headerClassName: 'w-20 min-w-20 whitespace-nowrap',
      },
    },
    {
      accessorFn: countRowErrors,
      cell: ({ row }) => (
        <ErrorSummaryCell
          errors={[
            ...row.original.errors,
            ...row.original.cellErrors.map((error) => error.message),
          ]}
        />
      ),
      header: 'Errors',
      id: 'errors',
      meta: {
        cellClassName: 'h-12 max-w-96 align-middle',
        headerClassName: 'w-96 min-w-96 whitespace-nowrap',
      },
      sortingFn: (a, b) =>
        countRowErrors(a.original) - countRowErrors(b.original),
    },
    ...valueColumns.map<ColumnDef<ImportRowResult>>((column) => ({
      cell: ({ row }) => {
        const cellErrors = row.original.cellErrors.filter(
          (error) => error.targetColumn === column
        );
        return (
          <span
            className={
              cellErrors.length > 0
                ? 'block max-w-64 truncate rounded bg-error/15 px-2 py-1 text-error'
                : 'block max-w-64 truncate'
            }
            title={[
              row.original.values[column],
              ...cellErrors.map((error) => error.message),
            ]
              .filter(Boolean)
              .join('\n')}
          >
            {row.original.values[column] || ' '}
          </span>
        );
      },
      header: column,
      id: column,
      meta: {
        cellClassName: 'h-12 max-w-64 align-middle',
        headerClassName: [
          'min-w-max whitespace-nowrap',
          columnsWithErrors.has(column) ? 'bg-error/15 text-error' : undefined,
        ]
          .filter(Boolean)
          .join(' '),
      },
    })),
  ];

  return (
    <div className="space-y-4">
      <div className="alert alert-error">
        <span>
          Import failed validation for {failedRows.toLocaleString()} of{' '}
          {validation.attemptedRows.toLocaleString()} attempted rows.
        </span>
      </div>

      {validation.fileErrors.length > 0 && (
        <div className="rounded-box border border-base-300 bg-base-100 p-4">
          <h3 className="mb-2 font-semibold">File issues</h3>
          <ErrorList
            errors={validation.fileErrors.map((error) =>
              [error.sourceHeader, error.targetColumn, error.message]
                .filter(Boolean)
                .join(': ')
            )}
          />
        </div>
      )}

      {rows.length > 0 && (
        <DataTable
          columns={columns}
          data={rows}
          filterPlaceholder="Search validation rows..."
          initialState={{
            pagination: {
              pageSize: 10,
            },
            sorting: [
              {
                desc: false,
                id: 'rowNum',
              },
            ],
          }}
          tableActions={
            <button
              className="btn btn-outline btn-sm"
              onClick={() => downloadValidationCsv(validation)}
              type="button"
            >
              Download CSV
            </button>
          }
          tableClassName="table-zebra"
        />
      )}
    </div>
  );
}

function ErrorList({ errors }: { errors: string[] }) {
  if (errors.length === 0) {
    return <span className="text-base-content/60">No errors</span>;
  }

  return (
    <ul className="list-disc space-y-1 pl-5">
      {errors.map((error, index) => (
        <li key={`${error}-${index}`}>{error}</li>
      ))}
    </ul>
  );
}

function ErrorSummaryCell({ errors }: { errors: string[] }) {
  if (errors.length === 0) {
    return (
      <span className="block max-w-96 truncate text-base-content/60">
        No errors
      </span>
    );
  }

  return (
    <span className="block max-w-96 truncate" title={errors.join('\n')}>
      {errors.join('; ')}
    </span>
  );
}

function countRowErrors(row: ImportRowResult) {
  return row.errors.length + row.cellErrors.length;
}

function rowHasErrors(row: ImportRowResult) {
  return countRowErrors(row) > 0;
}

function formatImportDate(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

function isValidationResponse(
  value: unknown
): value is ImportValidationResponse {
  return (
    typeof value === 'object' &&
    value !== null &&
    'succeeded' in value &&
    value.succeeded === false &&
    'rows' in value
  );
}

function downloadValidationCsv(validation: ImportValidationResponse) {
  const rows = validation.rows.flatMap((row) => {
    const rowErrors = row.errors.map((message) => ({
      column: '',
      message,
      rawValue: '',
      rowNum: row.rowNum,
      sourceHeader: '',
    }));
    const cellErrors = row.cellErrors.map((error) => ({
      column: error.targetColumn,
      message: error.message,
      rawValue: error.rawValue ?? '',
      rowNum: row.rowNum,
      sourceHeader: error.sourceHeader ?? '',
    }));

    return [...rowErrors, ...cellErrors];
  });

  const csv = toExcelCsv(rows, [
    { header: 'Row', key: 'rowNum' },
    { header: 'Column', key: 'column' },
    { header: 'Source Header', key: 'sourceHeader' },
    { header: 'Raw Value', key: 'rawValue' },
    { header: 'Error', key: 'message' },
  ]);

  downloadExcelCsv(csv, `${validation.dataset}-validation-errors.csv`);
}
