import { fetchJson } from '@/lib/api.ts';
import { queryOptions } from '@tanstack/react-query';

export type ProjectListStatus =
  | '204 outside college'
  | 'Clean'
  | 'Expired'
  | 'No PGM match'
  | 'Not in All Projects'
  | 'SFN mismatch'
  | string;

export interface ProjectListRow {
  accession: string | null;
  ae: string | null;
  awardNumber: string | null;
  nifaProject: string | null;
  department: string | null;
  pi: string | null;
  sfn: string | null;
  status: ProjectListStatus;
}

export interface ProjectListCounts {
  all: number;
  clean: number;
  issues: number;
}

export interface SfnDistribution {
  count: number;
  sfn: string;
}

export interface ProjectListSummary {
  activeNifa: number;
  allNifa: number;
  alnCodes: number;
  issuesToResolve: number;
  pgmRecords: number;
  sfnDistribution: SfnDistribution[];
}

export interface ProjectListResponse {
  counts: ProjectListCounts;
  cycleEnd: string;
  cycleStart: string;
  fiscalYear: string;
  rows: ProjectListRow[];
  summary: ProjectListSummary;
}

export function currentFiscalYear(date = new Date()): string {
  const calendarYear = date.getFullYear();
  const fiscalYear = date.getMonth() >= 9 ? calendarYear + 1 : calendarYear;
  return `FY${String(fiscalYear % 100).padStart(2, '0')}`;
}

export const projectListQueryOptions = (fiscalYear = currentFiscalYear()) =>
  queryOptions({
    queryFn: ({ signal }) =>
      fetchJson<ProjectListResponse>(
        `/api/projectlist?fy=${encodeURIComponent(fiscalYear)}`,
        {},
        signal
      ),
    queryKey: ['projectList', fiscalYear] as const,
  });
