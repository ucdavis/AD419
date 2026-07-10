import { downloadExcelCsv, toExcelCsv } from '@/lib/csv.ts';
import { fetchJson, HttpError } from '@/lib/api.ts';
import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryResult,
} from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';
import { useRef, useState } from 'react';
import { DataTable } from '@/shared/dataTable.tsx';

export type ImportDatasetId =
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

interface ImportUploadVariables {
  dataset: ImportDatasetId;
  file: File;
}

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
  validationStats?: ImportValidationStatsResponse | null;
}

interface ImportDatasetSummaryResponse {
  dataset: ImportDatasetId;
  displayName: string;
  lastImport?: RecentImportResponse | null;
}

interface ImportValidationStatsResponse {
  errorCount: number;
  fileErrorCount: number;
  rowCount: number;
  rowsWithErrors: number;
}

interface ImportValidationHistoryRow {
  cellErrors: ImportCellError[];
  errors: string[];
  rowNum: number;
}

interface ImportValidationHistoryResponse {
  attemptedRows: number;
  dataset: string;
  errorCount: number;
  fileErrors: ImportFileError[];
  filename?: string | null;
  rowCount: number;
  rows: ImportValidationHistoryRow[];
  rowsWithErrors: number;
  truncated: boolean;
}

interface ImportLogDetailResponse extends RecentImportResponse {
  validation?: ImportValidationHistoryResponse | null;
}

interface HistoricalValidationErrorRow {
  code: string;
  location: string;
  message: string;
  rawValue: string;
  rowLabel: string;
  sourceHeader: string;
}

export const datasetOptions: ImportDatasetOption[] = [
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
}: ImportUploadVariables): Promise<ImportSuccessResponse> {
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
    throw new HttpError(res.status, `/api/imports/${dataset}`, data);
  }

  if (!res.ok) {
    throw new HttpError(res.status, `/api/imports/${dataset}`, data);
  }

  return data as ImportSuccessResponse;
}

async function fetchRecentImports(): Promise<ImportDatasetSummaryResponse[]> {
  return fetchJson<ImportDatasetSummaryResponse[]>('/api/imports/recent');
}

async function fetchImportDetail(id: number): Promise<ImportLogDetailResponse> {
  return fetchJson<ImportLogDetailResponse>(`/api/imports/${id}`);
}

export function FlatFileImportPanel() {
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [dataset, setDataset] = useState<ImportDatasetId>('all-projects');
  const [file, setFile] = useState<File | null>(null);
  const [selectedImportId, setSelectedImportId] = useState<number | null>(null);
  const [validation, setValidation] = useState<ImportValidationResponse | null>(
    null
  );
  const [success, setSuccess] = useState<ImportSuccessResponse | null>(null);
  const recentImportsQuery = useQuery({
    queryFn: fetchRecentImports,
    queryKey: ['imports', 'recent'],
  });
  const importSummaries = getImportSummaries(recentImportsQuery.data);
  const importDetailQuery = useQuery({
    enabled: selectedImportId !== null,
    queryFn: () => fetchImportDetail(selectedImportId!),
    queryKey: ['imports', 'detail', selectedImportId],
  });

  const clearInputFileSelection = () => {
    setFile(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const mutation = useMutation({
    mutationFn: uploadImport,
    onError: (error, variables) => {
      setSuccess(null);
      if (error instanceof HttpError && isValidationResponse(error.body)) {
        setValidation(error.body);
        return;
      }

      setValidation({
        attemptedRows: 0,
        dataset: variables.dataset,
        fileErrors: [
          {
            code: 'upload_failed',
            message: 'The import could not be completed.',
          },
        ],
        filename: variables.file.name,
        rows: [],
        succeeded: false,
      });
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['imports', 'recent'] });
    },
    onSuccess: (response) => {
      setValidation(null);
      setSuccess(response);
      void queryClient.invalidateQueries({ queryKey: ['ad419Workflow'] });
    },
  });

  const canUpload = Boolean(file) && !mutation.isPending;

  const handleUpload = () => {
    if (!file || mutation.isPending) {
      return;
    }

    const selectedFile = file;
    clearInputFileSelection();
    setValidation(null);
    setSuccess(null);
    setSelectedImportId(null);
    mutation.mutate({ dataset, file: selectedFile });
  };

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
              const selectedFile = event.target.files?.[0];
              if (!selectedFile) {
                return;
              }

              setFile(selectedFile);
              setValidation(null);
              setSuccess(null);
            }}
            onClick={(event) => {
              event.currentTarget.value = '';
            }}
            ref={fileInputRef}
            type="file"
          />
        </label>

        <button
          className="btn btn-primary"
          disabled={!canUpload}
          onClick={handleUpload}
          type="button"
        >
          {mutation.isPending ? 'Importing' : 'Upload'}
        </button>
      </div>

      <RecentImportSummaryList
        isError={recentImportsQuery.isError}
        isLoading={recentImportsQuery.isLoading}
        onSelectImport={setSelectedImportId}
        selectedImportId={selectedImportId}
        summaries={importSummaries}
      />

      {selectedImportId !== null && (
        <HistoricalImportDetails query={importDetailQuery} />
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

export function FlatFileImportChecklistItem({
  completed,
  dataset,
  latestImport,
  markDonePending,
  onMarkDone,
  ready,
  stale,
  staleReason,
}: {
  completed: boolean;
  dataset: ImportDatasetId;
  latestImport?: RecentImportResponse | null;
  markDonePending: boolean;
  onMarkDone: () => void;
  ready: boolean;
  stale: boolean;
  staleReason?: string | null;
}) {
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [selectedImportId, setSelectedImportId] = useState<number | null>(null);
  const [validation, setValidation] = useState<ImportValidationResponse | null>(
    null
  );
  const [success, setSuccess] = useState<ImportSuccessResponse | null>(null);
  const importDetailQuery = useQuery({
    enabled: selectedImportId !== null,
    queryFn: () => fetchImportDetail(selectedImportId!),
    queryKey: ['imports', 'detail', selectedImportId],
  });
  const label = getDatasetLabel(dataset);

  const clearInputFileSelection = () => {
    setFile(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const mutation = useMutation({
    mutationFn: uploadImport,
    onError: (error, variables) => {
      setSuccess(null);
      if (error instanceof HttpError && isValidationResponse(error.body)) {
        setValidation(error.body);
        return;
      }

      setValidation({
        attemptedRows: 0,
        dataset: variables.dataset,
        fileErrors: [
          {
            code: 'upload_failed',
            message: 'The import could not be completed.',
          },
        ],
        filename: variables.file.name,
        rows: [],
        succeeded: false,
      });
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['imports', 'recent'] });
      void queryClient.invalidateQueries({
        queryKey: ['projectIdentification', 'setup'],
      });
    },
    onSuccess: (response) => {
      setValidation(null);
      setSuccess(response);
      setSelectedImportId(response.importLogId ?? null);
      void queryClient.invalidateQueries({ queryKey: ['ad419Workflow'] });
    },
  });

  const canUpload = Boolean(file) && !mutation.isPending;
  const canMarkDone = ready && !completed && !markDonePending;

  const handleUpload = () => {
    if (!file || mutation.isPending) {
      return;
    }

    const selectedFile = file;
    clearInputFileSelection();
    setValidation(null);
    setSuccess(null);
    setSelectedImportId(null);
    mutation.mutate({ dataset, file: selectedFile });
  };

  return (
    <div className="space-y-4">
      {latestImport ? (
        <RecentImportSummary
          importLog={latestImport}
          label={label}
          onSelectImport={setSelectedImportId}
          selected={latestImport.id === selectedImportId}
        />
      ) : (
        <div className="rounded border border-slate-200 bg-slate-50 p-3 text-sm text-slate-600">
          No import attempts found for {label}.
        </div>
      )}

      {stale && staleReason ? (
        <div className="alert alert-warning py-3 text-sm">
          <span>{staleReason}</span>
        </div>
      ) : null}

      <div className="grid gap-3 lg:grid-cols-[1fr_auto_auto] lg:items-end">
        <label className="form-control w-full">
          <span className="label-text">Import file</span>
          <input
            accept=".csv,.xlsx"
            className="file-input file-input-bordered w-full"
            onChange={(event) => {
              const selectedFile = event.target.files?.[0];
              if (!selectedFile) {
                return;
              }

              setFile(selectedFile);
              setValidation(null);
              setSuccess(null);
            }}
            onClick={(event) => {
              event.currentTarget.value = '';
            }}
            ref={fileInputRef}
            type="file"
          />
        </label>

        <button
          className="btn btn-outline"
          disabled={!canUpload}
          onClick={handleUpload}
          type="button"
        >
          {mutation.isPending ? 'Uploading' : 'Upload'}
        </button>

        <button
          className="btn btn-primary"
          disabled={!canMarkDone}
          onClick={onMarkDone}
          type="button"
        >
          {markDonePending
            ? 'Saving'
            : completed
              ? 'Done'
              : ready
                ? 'Mark done'
                : 'Awaiting successful import'}
        </button>
      </div>

      {selectedImportId !== null && (
        <HistoricalImportDetails query={importDetailQuery} />
      )}

      {success && (
        <div className="alert alert-success py-3 text-sm">
          <span>
            Imported {success.rowsImported.toLocaleString()} rows from{' '}
            {success.filename}. Mark this checklist item done when you are
            ready to use this import.
          </span>
        </div>
      )}

      {validation && <ValidationResults validation={validation} />}
    </div>
  );
}

function RecentImportSummaryList({
  isError,
  isLoading,
  onSelectImport,
  selectedImportId,
  summaries,
}: {
  isError: boolean;
  isLoading: boolean;
  onSelectImport: (id: number) => void;
  selectedImportId: number | null;
  summaries: ImportDatasetSummaryResponse[];
}) {
  return (
    <div className="rounded-box border border-base-300 bg-base-100 p-4">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <h3 className="font-semibold">Last import status</h3>
        {isLoading ? (
          <span className="loading loading-spinner loading-sm" />
        ) : null}
      </div>
      {isError ? (
        <p className="text-sm text-error">Import status is unavailable.</p>
      ) : (
        <div className="grid gap-3 lg:grid-cols-3">
          {summaries.map((summary) => (
            <RecentImportSummary
              importLog={summary.lastImport}
              key={summary.dataset}
              label={summary.displayName}
              onSelectImport={onSelectImport}
              selected={summary.lastImport?.id === selectedImportId}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function RecentImportSummary({
  importLog,
  label,
  onSelectImport,
  selected,
}: {
  importLog?: RecentImportResponse | null;
  label: string;
  onSelectImport: (id: number) => void;
  selected: boolean;
}) {
  if (!importLog) {
    return (
      <div
        aria-label={`${label} import status`}
        className="min-w-0 rounded-box border border-base-300 bg-base-200/40 p-3 text-sm"
      >
        <div className="flex flex-wrap items-center gap-2">
          <span className="badge badge-neutral">No imports yet</span>
          <span className="font-medium">{label}</span>
        </div>
        <p className="mt-2 text-base-content/60">No import attempts found.</p>
      </div>
    );
  }

  const status = getImportStatusPresentation(importLog.status);
  const rowCount = status.succeeded
    ? (importLog.rowsImported ?? 0)
    : importLog.attemptedRows;
  const validationStats =
    importLog.status === 'ValidationFailed' ? importLog.validationStats : null;

  return (
    <button
      aria-label={`${label} import status`}
      aria-pressed={selected}
      className={[
        'flex min-w-0 flex-col gap-3 rounded-box border bg-base-200/40 p-3 text-left text-sm transition hover:border-primary hover:bg-base-200 focus:outline-none focus:ring-2 focus:ring-primary',
        selected ? 'border-primary ring-2 ring-primary' : 'border-base-300',
      ]
        .filter(Boolean)
        .join(' ')}
      onClick={() => onSelectImport(importLog.id)}
      type="button"
    >
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-2">
          <span className={`badge ${status.badgeClassName}`}>
            {status.label}
          </span>
          <span className="font-medium">{label}</span>
        </div>
        <p
          className="mt-1 truncate text-base-content/70"
          title={importLog.filename}
        >
          {importLog.filename}
        </p>
      </div>
      <div className="text-base-content/70">
        <div>{rowCount.toLocaleString()} rows</div>
        {validationStats ? (
          <div>{formatValidationStats(validationStats)}</div>
        ) : null}
        <time dateTime={importLog.importedAt}>
          {formatImportDate(importLog.importedAt)}
        </time>
      </div>
    </button>
  );
}

function formatValidationStats(stats: ImportValidationStatsResponse) {
  const rowLabel = stats.rowsWithErrors === 1 ? 'row' : 'rows';
  const fileIssueLabel =
    stats.fileErrorCount === 1 ? 'file issue' : 'file issues';
  const fileIssues =
    stats.fileErrorCount > 0
      ? `; ${stats.fileErrorCount.toLocaleString()} ${fileIssueLabel}`
      : '';
  const rowErrors = `${stats.errorCount.toLocaleString()} errors across ${stats.rowsWithErrors.toLocaleString()} ${rowLabel}`;

  return `${rowErrors}${fileIssues}`;
}

function HistoricalImportDetails({
  query,
}: {
  query: UseQueryResult<ImportLogDetailResponse>;
}) {
  if (query.isLoading) {
    return (
      <div className="rounded-box border border-base-300 bg-base-100 p-4 text-sm text-base-content/70">
        Loading import details...
      </div>
    );
  }

  if (query.isError || !query.data) {
    return (
      <div className="alert alert-error">
        <span>Import details could not be loaded.</span>
      </div>
    );
  }

  const detail = query.data;
  const validation = detail.validation;
  if (!validation || validation.errorCount === 0) {
    return (
      <div className="rounded-box border border-base-300 bg-base-100 p-4">
        <h3 className="font-semibold">Validation history</h3>
        <p className="mt-2 text-sm text-base-content/70">
          No validation errors were recorded for {detail.filename}.
        </p>
      </div>
    );
  }

  const rows = getHistoricalValidationRows(validation);
  const columns: ColumnDef<HistoricalValidationErrorRow>[] = [
    {
      accessorKey: 'rowLabel',
      header: 'Row',
      meta: {
        cellClassName: 'h-12 w-24 min-w-24 align-middle',
        headerClassName: 'w-24 min-w-24 whitespace-nowrap',
      },
    },
    {
      accessorKey: 'location',
      header: 'Column',
      meta: {
        cellClassName: 'h-12 min-w-56 align-middle',
        headerClassName: 'min-w-56 whitespace-nowrap',
      },
    },
    {
      accessorKey: 'sourceHeader',
      header: 'Source Header',
      meta: {
        cellClassName: 'h-12 min-w-56 align-middle',
        headerClassName: 'min-w-56 whitespace-nowrap',
      },
    },
    {
      accessorKey: 'rawValue',
      cell: ({ row }) => (
        <span className="block max-w-64 truncate" title={row.original.rawValue}>
          {row.original.rawValue || ' '}
        </span>
      ),
      header: 'Raw Value',
      meta: {
        cellClassName: 'h-12 max-w-64 align-middle',
        headerClassName: 'min-w-48 whitespace-nowrap',
      },
    },
    {
      accessorKey: 'message',
      cell: ({ row }) => (
        <span className="block max-w-96 truncate" title={row.original.message}>
          {row.original.message}
        </span>
      ),
      header: 'Error',
      meta: {
        cellClassName: 'h-12 max-w-96 align-middle',
        headerClassName: 'min-w-96 whitespace-nowrap',
      },
    },
    {
      accessorKey: 'code',
      header: 'Code',
      meta: {
        cellClassName: 'h-12 min-w-48 align-middle',
        headerClassName: 'min-w-48 whitespace-nowrap',
      },
    },
  ];

  return (
    <div className="space-y-4">
      <div>
        <h3 className="font-semibold">Validation history</h3>
        <p className="mt-1 text-sm text-base-content/70">
          {validation.errorCount.toLocaleString()} validation errors across{' '}
          {validation.rowsWithErrors.toLocaleString()} rows in {detail.filename}.
        </p>
      </div>

      <DataTable
        columns={columns}
        data={rows}
        filterPlaceholder="Search validation errors..."
        initialState={{
          pagination: {
            pageSize: 10,
          },
        }}
        tableClassName="table-zebra"
      />
    </div>
  );
}

function getHistoricalValidationRows(
  validation: ImportValidationHistoryResponse
): HistoricalValidationErrorRow[] {
  const fileErrors = validation.fileErrors.map((error) => ({
    code: error.code,
    location: error.targetColumn ?? 'File',
    message: error.message,
    rawValue: '',
    rowLabel: 'File',
    sourceHeader: error.sourceHeader ?? '',
  }));
  const rowErrors = validation.rows.flatMap((row) => [
    ...row.errors.map((message) => ({
      code: 'row_error',
      location: 'Row',
      message,
      rawValue: '',
      rowLabel: row.rowNum.toLocaleString(),
      sourceHeader: '',
    })),
    ...row.cellErrors.map((error) => ({
      code: error.code,
      location: error.targetColumn,
      message: error.message,
      rawValue: error.rawValue ?? '',
      rowLabel: row.rowNum.toLocaleString(),
      sourceHeader: error.sourceHeader ?? '',
    })),
  ]);

  return [...fileErrors, ...rowErrors];
}

function getImportSummaries(
  summaries?: ImportDatasetSummaryResponse[]
): ImportDatasetSummaryResponse[] {
  return datasetOptions.map((option) => {
    const summary = summaries?.find((item) => item.dataset === option.id);

    return {
      dataset: option.id,
      displayName: summary?.displayName ?? option.label,
      lastImport: summary?.lastImport ?? null,
    };
  });
}

function getDatasetLabel(dataset: ImportDatasetId): string {
  return datasetOptions.find((option) => option.id === dataset)?.label ?? dataset;
}

function getImportStatusPresentation(status: string) {
  switch (status) {
    case 'Succeeded':
      return {
        badgeClassName: 'badge-success',
        label: 'Succeeded',
        succeeded: true,
      };
    case 'ValidationFailed':
      return {
        badgeClassName: 'badge-error',
        label: 'Validation failed',
        succeeded: false,
      };
    case 'PersistenceFailed':
      return {
        badgeClassName: 'badge-error',
        label: 'Save failed',
        succeeded: false,
      };
    default:
      return {
        badgeClassName: 'badge-error',
        label: 'Failed',
        succeeded: false,
      };
  }
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
  );
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
