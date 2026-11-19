import { fetchJson } from '../lib/api.ts';
import { queryOptions, useMutation, useQueryClient } from '@tanstack/react-query';

export interface ReportEnvelope<T> {
  cycleEnd: string;
  cycleStart: string;
  data: T;
  fiscalYear: string;
}

export interface AutoAssociationBuild {
  associationRows: number;
  buildId: number;
  builtAt: string;
  cycleEnd: string;
  cycleStart: string;
  excludedProjects: number;
  misclassified204Rows: number;
  summaryRows: number;
}

export interface AssociatedProject {
  accessionNumber: string;
  aeProjects: string | null;
  expenses: number;
  fte: number;
  nifaProjectNumber: string;
  projectDirector: string | null;
  title: string | null;
}

export type UnassociatedReason =
  | 'Misclassified204'
  | 'NoAeProject'
  | 'NoEmployee'
  | 'NoFteLine'
  | 'NoProject'
  | 'NoRuleMatched'
  | 'ProjectExcluded';

export interface UnassociatedExpense {
  // Null on rows from a build made before account joined the summary.
  account: string | null;
  employeeId: string | null;
  employeeName: string | null;
  expenseId: number;
  expenses: number;
  expenseSfn: string | null;
  financialDepartment: string | null;
  fte: number;
  // The job SFN (FTE line). expenseSfn is the fund SFN.
  fteSfn: string | null;
  fund: string | null;
  orgR: string;
  project: string | null;
  reason: UnassociatedReason;
  source: string;
}

export interface Rule204Report {
  misclassified: UnassociatedExpense[];
  projects: AssociatedProject[];
  unassociated: UnassociatedExpense[];
}

export interface Rule20xPi {
  employeeId: string;
  employeeName: string | null;
  expenses: number;
  fte: number;
  projectCount: number;
}

export interface Rule20xSfn {
  expenses: number;
  fte: number;
  label: string | null;
  pis: Rule20xPi[];
  projectCount: number;
  sfn: string;
}

export interface Rule20xReport {
  sfns: Rule20xSfn[];
  unassociated: UnassociatedExpense[];
}

export interface Rule220Report {
  projects: AssociatedProject[];
  unassociated: UnassociatedExpense[];
}

export interface ExcludedProject {
  accessionNumber: string;
  aeProjects: string | null;
  nifaProjectNumber: string;
  projectDirector: string | null;
  title: string | null;
  total: number;
}

export interface FteOverOne {
  employeeId: string;
  employeeName: string | null;
  fte: number;
  rowCount: number;
}

// PI payroll the FTE line rule moved: titleFteSfn is the line the title gives
// (242), fteSfn the line it reports on (241).
export interface PiFteAdjustment {
  employeeId: string;
  employeeName: string | null;
  expenses: number;
  fte: number;
  fteSfn: string;
  jobCode: string;
  rowCount: number;
  titleFteSfn: string;
  titleName: string | null;
}

export interface PreAssociationTotal {
  expenses: number;
  expenseSfn: string | null;
  financialDepartment: string | null;
  financialDepartmentName: string | null;
  fte: number;
  fteSfn: string | null;
  orgR: string;
  sfnLabel: string | null;
}

export const AUTO_ASSOCIATIONS_KEYS = {
  build: ['autoAssociations', 'build'] as const,
  excluded: ['autoAssociations', 'excluded'] as const,
  fte: ['autoAssociations', 'fte'] as const,
  piFte: ['autoAssociations', 'piFte'] as const,
  rule204: ['autoAssociations', 'rule204'] as const,
  rule20x: ['autoAssociations', 'rule20x'] as const,
  rule220: ['autoAssociations', 'rule220'] as const,
  totals: ['autoAssociations', 'totals'] as const,
};

export const REBUILD_AUTO_ASSOCIATIONS_MUTATION_KEY = ['autoAssociations', 'rebuild'] as const;

const report = <T,>(url: string, signal: AbortSignal) =>
  fetchJson<ReportEnvelope<T>>(url, {}, signal).then((r) => r.data);

// Reruns the build for the current cycle. Every report reads the staging
// tables the build replaces, so all of them reload once it finishes. Reads
// still running are cancelled first: invalidating a query that has no data
// yet would wait for its running read, which may have read the previous build.
export const useRebuildAutoAssociations = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () =>
      fetchJson<ReportEnvelope<AutoAssociationBuild | null>>('/api/autoassociations/rebuild', {
        method: 'POST',
      }),
    mutationKey: REBUILD_AUTO_ASSOCIATIONS_MUTATION_KEY,
    onSuccess: async () => {
      await queryClient.cancelQueries({ queryKey: ['autoAssociations'] });
      await queryClient.invalidateQueries({ queryKey: ['autoAssociations'] });
    },
  });
};

export const autoAssociationBuildQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) => report<AutoAssociationBuild | null>('/api/autoassociations/build', signal),
    queryKey: AUTO_ASSOCIATIONS_KEYS.build,
  });

export const rule204ReportQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) => report<Rule204Report>('/api/autoassociations/rule-204', signal),
    queryKey: AUTO_ASSOCIATIONS_KEYS.rule204,
  });

export const rule20xReportQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) => report<Rule20xReport>('/api/autoassociations/rule-20x', signal),
    queryKey: AUTO_ASSOCIATIONS_KEYS.rule20x,
  });

export const rule220ReportQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) => report<Rule220Report>('/api/autoassociations/rule-220', signal),
    queryKey: AUTO_ASSOCIATIONS_KEYS.rule220,
  });

export const excludedProjectsQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) => report<ExcludedProject[]>('/api/autoassociations/excluded-projects', signal),
    queryKey: AUTO_ASSOCIATIONS_KEYS.excluded,
  });

export const fteOverOneQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) => report<FteOverOne[]>('/api/autoassociations/fte-over-one', signal),
    queryKey: AUTO_ASSOCIATIONS_KEYS.fte,
  });

export const piFteAdjustmentsQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) => report<PiFteAdjustment[]>('/api/autoassociations/pi-fte-adjustments', signal),
    queryKey: AUTO_ASSOCIATIONS_KEYS.piFte,
  });

export const preAssociationTotalsQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) => report<PreAssociationTotal[]>('/api/autoassociations/pre-association-totals', signal),
    queryKey: AUTO_ASSOCIATIONS_KEYS.totals,
  });
