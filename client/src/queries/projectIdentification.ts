import { fetchJson } from '@/lib/api.ts';
import { queryOptions } from '@tanstack/react-query';

export type ChecklistStatus = 'active' | 'done' | 'locked' | 'ready' | 'stale';

export type ChecklistKind = 'action' | 'import' | 'review' | 'select' | 'upload';

export interface RecentImportResponse {
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

export interface ImportValidationStatsResponse {
  errorCount: number;
  fileErrorCount: number;
  rowCount: number;
  rowsWithErrors: number;
}

export interface ChecklistSource {
  completedAt?: string | null;
  importLogId?: number | null;
  key?: string | null;
  rows?: number | null;
}

export interface ProjectChecklistItem {
  completed: boolean;
  hint: string;
  id: string;
  kind: ChecklistKind;
  label: string;
  latestImport?: RecentImportResponse | null;
  number: number;
  ready: boolean;
  source?: ChecklistSource | null;
  stale: boolean;
  staleReason?: string | null;
  status: ChecklistStatus;
}

export interface FiscalPeriodOption {
  cycleEnd: string;
  cycleStart: string;
  fiscalYear: string;
  label: string;
}

export interface ProjectIdentificationSetupResponse {
  checklistItems: ProjectChecklistItem[];
  completedCount: number;
  cycleEnd: string;
  cycleStart: string;
  fiscalPeriodOptions: FiscalPeriodOption[];
  fiscalYear: string;
  totalCount: number;
  workflowRunId: number;
}

export const projectIdentificationSetupQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) =>
      fetchJson<ProjectIdentificationSetupResponse>(
        '/api/projectidentification/setup',
        {},
        signal
      ),
    queryKey: ['projectIdentification', 'setup'] as const,
  });

export async function confirmFiscalPeriod(fiscalYear: string) {
  return fetchJson<ProjectIdentificationSetupResponse>(
    '/api/projectidentification/fiscal-period',
    {
      body: JSON.stringify({ fiscalYear }),
      headers: {
        'Content-Type': 'application/json',
      },
      method: 'PUT',
    }
  );
}

export async function setChecklistItemCompletion(
  itemId: string,
  completed: boolean
) {
  return fetchJson<ProjectIdentificationSetupResponse>(
    `/api/projectidentification/checklist/${encodeURIComponent(itemId)}`,
    {
      body: JSON.stringify({ completed }),
      headers: {
        'Content-Type': 'application/json',
      },
      method: 'PUT',
    }
  );
}

export async function finalizeProjects() {
  return fetchJson<ProjectIdentificationSetupResponse>(
    '/api/projectidentification/finalize',
    {
      method: 'POST',
    }
  );
}
