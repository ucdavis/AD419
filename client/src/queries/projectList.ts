import { fetchJson } from '@/lib/api.ts';
import { queryOptions } from '@tanstack/react-query';

export type ProjectListStatus =
  | 'Clean'
  | 'Excluded'
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
  excluded: number;
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
  excludedNifa: number;
  issuesToResolve: number;
  pgmRecords: number;
  sfnDistribution: SfnDistribution[];
}

export interface ProjectListResponse {
  counts: ProjectListCounts;
  cycleEnd: string;
  cycleStart: string;
  excludedRows: ProjectListRow[];
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
  description: string;
  isRecommended: boolean;
  sfn: string;
  source: string | null;
}

export interface ProjectResolutionEditsResponse {
  hasResolutionEdits: boolean;
}

export const projectListQueryOptions = (fiscalYear: string) =>
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
  fiscalYear: string,
  accession: string,
  search: string
) {
  const params = new URLSearchParams();
  params.set('fy', fiscalYear);
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
      fiscalYear,
      accession,
      'allProjectCandidates',
      query,
    ] as const,
  });
}

export function pgmAwardCandidatesQueryOptions(
  fiscalYear: string,
  accession: string,
  search: string
) {
  const params = new URLSearchParams();
  params.set('fy', fiscalYear);
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
      fiscalYear,
      accession,
      'pgmAwardCandidates',
      query,
    ] as const,
  });
}

export function sfnCandidatesQueryOptions(
  fiscalYear: string,
  accession: string
) {
  const params = new URLSearchParams({ fy: fiscalYear });

  return queryOptions({
    queryFn: ({ signal }) =>
      fetchJson<SfnCandidate[]>(
        `${projectResolutionUrl(accession, 'sfn-candidates')}?${params.toString()}`,
        {},
        signal
      ),
    queryKey: ['projectList', fiscalYear, accession, 'sfnCandidates'] as const,
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

function projectResolutionActionUrl(
  fiscalYear: string,
  accession: string,
  path: string
) {
  const params = new URLSearchParams({ fy: fiscalYear });
  return `${projectResolutionUrl(accession, path)}?${params.toString()}`;
}

export async function excludeProject(fiscalYear: string, accession: string) {
  return fetchJson<void>(
    projectResolutionActionUrl(fiscalYear, accession, 'exclude'),
    {
      method: 'POST',
    }
  );
}

export async function linkAllProject(
  fiscalYear: string,
  accession: string,
  allProjectId: number
) {
  return fetchJson<void>(
    projectResolutionActionUrl(fiscalYear, accession, 'link-all-project'),
    {
      body: JSON.stringify({ allProjectId }),
      method: 'POST',
    }
  );
}

export async function linkPgmAward(
  fiscalYear: string,
  accession: string,
  awardKey: string
) {
  return fetchJson<void>(
    projectResolutionActionUrl(fiscalYear, accession, 'link-pgm-award'),
    {
      body: JSON.stringify({ awardKey }),
      method: 'POST',
    }
  );
}

export async function setProjectSfn(
  fiscalYear: string,
  accession: string,
  sfn: string
) {
  return fetchJson<void>(
    projectResolutionActionUrl(fiscalYear, accession, 'set-sfn'),
    {
      body: JSON.stringify({ sfn }),
      method: 'POST',
    }
  );
}
