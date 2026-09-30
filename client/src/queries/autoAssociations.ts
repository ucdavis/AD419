import { fetchJson } from '../lib/api.ts';
import { queryOptions } from '@tanstack/react-query';

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
  employeeId: string | null;
  employeeName: string | null;
  expenseId: number;
  expenses: number;
  expenseSfn: string | null;
  financialDepartment: string | null;
  fte: number;
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

export interface PreAssociationTotal {
  expenses: number;
  expenseSfn: string | null;
  financialDepartment: string | null;
  financialDepartmentName: string | null;
  fte: number;
  orgR: string;
  sfnLabel: string | null;
}

export interface UnmatchedJobCode {
  amount: number;
  employeeCount: number;
  fte: number;
  jobCode: string | null;
  reason: string;
  rowCount: number;
  staffTypeCode: string | null;
  titleName: string | null;
}

export interface UnmatchedJobCodesResponse {
  cycleEnd: string;
  cycleStart: string;
  fiscalYear: string;
  rows: UnmatchedJobCode[];
}

export const AUTO_ASSOCIATIONS_KEYS = {
  build: ['autoAssociations', 'build'] as const,
  excluded: ['autoAssociations', 'excluded'] as const,
  fte: ['autoAssociations', 'fte'] as const,
  jobCodes: ['autoAssociations', 'jobCodes'] as const,
  rule204: ['autoAssociations', 'rule204'] as const,
  rule20x: ['autoAssociations', 'rule20x'] as const,
  rule220: ['autoAssociations', 'rule220'] as const,
  totals: ['autoAssociations', 'totals'] as const,
};

const report = <T,>(url: string) => fetchJson<ReportEnvelope<T>>(url).then((r) => r.data);

export const autoAssociationBuildQueryOptions = () =>
  queryOptions({
    queryFn: () => report<AutoAssociationBuild | null>('/api/autoassociations/build'),
    queryKey: AUTO_ASSOCIATIONS_KEYS.build,
  });

export const rule204ReportQueryOptions = () =>
  queryOptions({
    queryFn: () => report<Rule204Report>('/api/autoassociations/rule-204'),
    queryKey: AUTO_ASSOCIATIONS_KEYS.rule204,
  });

export const rule20xReportQueryOptions = () =>
  queryOptions({
    queryFn: () => report<Rule20xReport>('/api/autoassociations/rule-20x'),
    queryKey: AUTO_ASSOCIATIONS_KEYS.rule20x,
  });

export const rule220ReportQueryOptions = () =>
  queryOptions({
    queryFn: () => report<Rule220Report>('/api/autoassociations/rule-220'),
    queryKey: AUTO_ASSOCIATIONS_KEYS.rule220,
  });

export const excludedProjectsQueryOptions = () =>
  queryOptions({
    queryFn: () => report<ExcludedProject[]>('/api/autoassociations/excluded-projects'),
    queryKey: AUTO_ASSOCIATIONS_KEYS.excluded,
  });

export const fteOverOneQueryOptions = () =>
  queryOptions({
    queryFn: () => report<FteOverOne[]>('/api/autoassociations/fte-over-one'),
    queryKey: AUTO_ASSOCIATIONS_KEYS.fte,
  });

export const preAssociationTotalsQueryOptions = () =>
  queryOptions({
    queryFn: () => report<PreAssociationTotal[]>('/api/autoassociations/pre-association-totals'),
    queryKey: AUTO_ASSOCIATIONS_KEYS.totals,
  });

export const unmatchedJobCodesQueryOptions = () =>
  queryOptions({
    queryFn: () =>
      fetchJson<UnmatchedJobCodesResponse>('/api/ExpenseReview/unmatched-job-codes').then((r) => r.rows),
    queryKey: AUTO_ASSOCIATIONS_KEYS.jobCodes,
  });
