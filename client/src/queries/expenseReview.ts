import { fetchJson } from '@/lib/api.ts';
import { queryOptions } from '@tanstack/react-query';

export type ExpenseReviewIncludeState = 'all' | 'included' | 'excluded';

export type ExpenseReviewSortBy =
  | 'account'
  | 'accountingPeriod'
  | 'activity'
  | 'aeProject'
  | 'amount'
  | 'entity'
  | 'financialDept'
  | 'fund'
  | 'included'
  | 'program'
  | 'purpose'
  | 'sfn'
  | 'source';

export type ExpenseReviewSortDirection = 'asc' | 'desc';

export interface ExpenseReviewCodeName {
  code: string | null;
  name: string | null;
}

export interface ExpenseReviewExclusionReason {
  amount: number;
  code: string;
  label: string;
  rowCount: number;
}

export interface ExpenseReviewTransaction {
  account: ExpenseReviewCodeName;
  accountingPeriod: string | null;
  activity: ExpenseReviewCodeName;
  aeProject: ExpenseReviewCodeName;
  amount: number | null;
  entity: ExpenseReviewCodeName;
  exclusionReasons: ExpenseReviewExclusionReason[];
  financialDept: ExpenseReviewCodeName;
  fund: ExpenseReviewCodeName;
  id: string;
  included: boolean;
  program: ExpenseReviewCodeName;
  purpose: ExpenseReviewCodeName;
  sfn: string | null;
  sfnLabel: string | null;
  source: 'AE' | 'UCP';
}

export interface ExpenseReviewCounts {
  all: number;
  excluded: number;
  included: number;
}

export interface ExpenseReviewTransactionsResponse {
  counts: ExpenseReviewCounts;
  cycleEnd: string;
  cycleStart: string;
  fiscalYear: string;
  page: number;
  pageCount: number;
  pageSize: number;
  rows: ExpenseReviewTransaction[];
  totalCount: number;
}

export interface ExpenseReviewFilterOption {
  label: string;
  value: string;
}

export interface ExpenseReviewFilterOptionsResponse {
  accountingPeriods: ExpenseReviewFilterOption[];
  accounts: ExpenseReviewFilterOption[];
  activities: ExpenseReviewFilterOption[];
  aeProjects: ExpenseReviewFilterOption[];
  entities: ExpenseReviewFilterOption[];
  exclusionReasons: ExpenseReviewFilterOption[];
  financialDepts: ExpenseReviewFilterOption[];
  funds: ExpenseReviewFilterOption[];
  programs: ExpenseReviewFilterOption[];
  purposes: ExpenseReviewFilterOption[];
  sfns: ExpenseReviewFilterOption[];
  sources: ExpenseReviewFilterOption[];
}

export interface ExpenseReviewFilters {
  account: string[];
  accountingPeriod: string[];
  activity: string[];
  aeProject: string[];
  entity: string[];
  exclusionReason: string[];
  financialDept: string[];
  fund: string[];
  program: string[];
  purpose: string[];
  sfn: string[];
  source: string[];
}

export interface ExpenseReviewTransactionsParams {
  displayByPeriod: boolean;
  filters: ExpenseReviewFilters;
  includeState: ExpenseReviewIncludeState;
  page: number;
  pageSize: number;
  sortBy?: ExpenseReviewSortBy;
  sortDirection?: ExpenseReviewSortDirection;
}

export interface ExpenseReviewTransactionsCsvParams {
  displayByPeriod: boolean;
  filters: ExpenseReviewFilters;
  includeState: ExpenseReviewIncludeState;
  sortBy?: ExpenseReviewSortBy;
  sortDirection?: ExpenseReviewSortDirection;
}

export const EMPTY_EXPENSE_REVIEW_FILTERS: ExpenseReviewFilters = {
  account: [],
  accountingPeriod: [],
  activity: [],
  aeProject: [],
  entity: [],
  exclusionReason: [],
  financialDept: [],
  fund: [],
  program: [],
  purpose: [],
  sfn: [],
  source: [],
};

const filterQueryParams: Array<keyof ExpenseReviewFilters> = [
  'entity',
  'financialDept',
  'fund',
  'account',
  'aeProject',
  'accountingPeriod',
  'purpose',
  'program',
  'activity',
  'sfn',
  'source',
  'exclusionReason',
];

function appendParams(
  params: Omit<ExpenseReviewTransactionsParams, 'page' | 'pageSize'> &
    Partial<Pick<ExpenseReviewTransactionsParams, 'page' | 'pageSize'>>,
  includePagination: boolean
) {
  const search = new URLSearchParams({
    displayByPeriod: params.displayByPeriod ? 'true' : 'false',
    includeState: params.includeState,
  });

  if (includePagination) {
    search.set('page', String(params.page));
    search.set('pageSize', String(params.pageSize));
  }

  if (params.sortBy) {
    search.set('sortBy', params.sortBy);
  }
  if (params.sortDirection) {
    search.set('sortDirection', params.sortDirection);
  }

  for (const filter of filterQueryParams) {
    for (const value of params.filters[filter]) {
      search.append(filter, value);
    }
  }

  return search;
}

export const expenseReviewTransactionsQueryOptions = (
  params: ExpenseReviewTransactionsParams
) =>
  queryOptions({
    queryFn: ({ signal }) =>
      fetchJson<ExpenseReviewTransactionsResponse>(
        `/api/expensereview/transactions?${appendParams(params, true)}`,
        {},
        signal
      ),
    queryKey: ['expenseReview', 'transactions', params],
  });

export function buildExpenseReviewTransactionsCsvUrl(
  params: ExpenseReviewTransactionsCsvParams
) {
  const search = appendParams(params, false);

  return `/api/expensereview/transactions.csv?${search}`;
}

export const expenseReviewFilterOptionsQueryOptions = () =>
  queryOptions({
    queryFn: ({ signal }) =>
      fetchJson<ExpenseReviewFilterOptionsResponse>(
        '/api/expensereview/filters',
        {},
        signal
      ),
    queryKey: ['expenseReview', 'filters'],
  });
