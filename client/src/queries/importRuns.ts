import { fetchJson } from '@/lib/api.ts';
import { queryOptions } from '@tanstack/react-query';

export interface ImportRunStage {
  completedAt: string | null;
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

export function defaultCycleDates(today = new Date()): {
  cycleEnd: string;
  cycleStart: string;
} {
  const fyEndYear =
    today.getMonth() >= 9 ? today.getFullYear() + 1 : today.getFullYear();
  return {
    cycleEnd: `${fyEndYear}-09-30`,
    cycleStart: `${fyEndYear - 1}-10-01`,
  };
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
