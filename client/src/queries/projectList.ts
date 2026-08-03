import { fetchJson } from '@/lib/api.ts';
import { queryOptions } from '@tanstack/react-query';

export type ProjectListStatus =
  | 'Clean'
  | 'No PGM match'
  | 'Not in All Projects'
  | 'SFN mismatch'
  | string;

export interface ProjectListRow {
  accession: string | null;
  ae: string | null;
  awardNumber: string | null;
  department: string | null;
  is204: boolean;
  nifaProject: string | null;
  notes: string | null;
  pdEmailAddress: string | null;
  pi: string | null;
  sfn: string | null;
  status: ProjectListStatus;
  ucPathName: string | null;
  ucpEmployeeId: string | null;
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

export interface AllProjectCandidate {
  accessionNumber: string | null;
  allProjectId: number;
  awardNumber: string | null;
  department: string | null;
  projectDirector: string | null;
  projectEndDate: string | null;
  projectNumber: string | null;
  projectStartDate: string | null;
  title: string | null;
}

export interface PgmAwardCandidate {
  awardKey: string;
  awardName: string | null;
  pgmSfnBucket: string | null;
  principalInvestigatorNames: string | null;
  projectNumbers: string | null;
  sponsorAwardNumber: string | null;
}

export interface SfnCandidate {
  sfn: string;
  source: string;
}

export interface ProjectResolutionEditsResponse {
  hasResolutionEdits: boolean;
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

const projectResolutionUrl = (accession: string, path: string) =>
  `/api/projectlist/${encodeURIComponent(accession)}/${path}`;

export function allProjectCandidatesQueryOptions(
  accession: string,
  search: string
) {
  const params = new URLSearchParams();
  if (search.trim()) {
    params.set('search', search.trim());
  }

  const query = params.toString();

  return queryOptions({
    queryFn: ({ signal }) =>
      fetchJson<AllProjectCandidate[]>(
        `${projectResolutionUrl(accession, 'all-project-candidates')}${
          query ? `?${query}` : ''
        }`,
        {},
        signal
      ),
    queryKey: [
      'projectList',
      accession,
      'allProjectCandidates',
      search,
      query,
    ] as const,
  });
}

export function pgmAwardCandidatesQueryOptions(
  accession: string,
  search: string
) {
  const params = new URLSearchParams();
  if (search.trim()) {
    params.set('search', search.trim());
  }

  const query = params.toString();

  return queryOptions({
    queryFn: ({ signal }) =>
      fetchJson<PgmAwardCandidate[]>(
        `${projectResolutionUrl(accession, 'pgm-award-candidates')}${
          query ? `?${query}` : ''
        }`,
        {},
        signal
      ),
    queryKey: [
      'projectList',
      accession,
      'pgmAwardCandidates',
      search,
      query,
    ] as const,
  });
}

export function sfnCandidatesQueryOptions(accession: string) {
  return queryOptions({
    queryFn: ({ signal }) =>
      fetchJson<SfnCandidate[]>(
        projectResolutionUrl(accession, 'sfn-candidates'),
        {},
        signal
      ),
    queryKey: ['projectList', accession, 'sfnCandidates'] as const,
  });
}

export const projectResolutionEditsQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) =>
      fetchJson<ProjectResolutionEditsResponse>(
        '/api/projectlist/resolution-edits',
        {},
        signal
      ),
    queryKey: ['projectList', 'resolutionEdits'] as const,
  });

export async function excludeProject(accession: string) {
  return fetchJson<void>(projectResolutionUrl(accession, 'exclude'), {
    method: 'POST',
  });
}

export async function linkAllProject(accession: string, allProjectId: number) {
  return fetchJson<void>(projectResolutionUrl(accession, 'link-all-project'), {
    body: JSON.stringify({ allProjectId }),
    method: 'POST',
  });
}

export async function linkPgmAward(accession: string, awardKey: string) {
  return fetchJson<void>(projectResolutionUrl(accession, 'link-pgm-award'), {
    body: JSON.stringify({ awardKey }),
    method: 'POST',
  });
}

export async function setProjectSfn(accession: string, sfn: string) {
  return fetchJson<void>(projectResolutionUrl(accession, 'set-sfn'), {
    body: JSON.stringify({ sfn }),
    method: 'POST',
  });
}
