import { fetchJson } from '@/lib/api.ts';
import { queryOptions } from '@tanstack/react-query';

export interface ImportRunStage {
  completedAt: string | null;
  detail: string | null;
  errorDetail: string | null;
  name: string;
  ordinal: number;
  rowCount: number | null;
  startedAt: string | null;
  status: 'Failed' | 'Pending' | 'Running' | 'Succeeded';
}

export interface ImportRun {
  completedAt: string | null;
  cycleEnd: string;
  cycleStart: string;
  id: number;
  stages: ImportRunStage[];
  startedAt: string;
  status: 'Failed' | 'Running' | 'Succeeded';
  triggeredByName: string | null;
}

// Mirrors ImportSql.BufferedWindow on the server: months clamp to the last
// day of the target month, matching .NET AddMonths.
export function bufferedImportWindow(
  cycleStart: string,
  cycleEnd: string
): { windowEnd: string; windowStart: string } {
  return {
    windowEnd: addMonths(cycleEnd, 3),
    windowStart: addMonths(cycleStart, -3),
  };
}

function addMonths(isoDate: string, months: number): string {
  const [year, month, day] = isoDate.split('-').map(Number);
  const totalMonths = year * 12 + (month - 1) + months;
  const targetYear = Math.floor(totalMonths / 12);
  const targetMonth = (totalMonths % 12) + 1;
  const lastDay = new Date(Date.UTC(targetYear, targetMonth, 0)).getUTCDate();
  const targetDay = Math.min(day, lastDay);
  return `${targetYear}-${String(targetMonth).padStart(2, '0')}-${String(
    targetDay
  ).padStart(2, '0')}`;
}

const IMPORT_RUN_KEY = ['importRun'] as const;

export const importRunQueryOptions = () =>
  queryOptions({
    queryFn: async ({ signal }): Promise<ImportRun | null> => {
      const response = await fetch('/api/importruns/current', { signal });
      if (response.status === 204) {
        return null;
      }
      if (!response.ok) {
        throw new Error(`Failed to load import run (${response.status})`);
      }
      return (await response.json()) as ImportRun;
    },
    queryKey: IMPORT_RUN_KEY,
    refetchInterval: (query) =>
      query.state.data?.status === 'Running' ? 2000 : false,
  });

export function startImportRun(body: {
  cycleEnd: string;
  cycleStart: string;
}): Promise<ImportRun> {
  return fetchJson<ImportRun>('/api/importruns', {
    body: JSON.stringify(body),
    method: 'POST',
  });
}
