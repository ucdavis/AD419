import { fetchJson } from '@/lib/api.ts';
import { queryOptions } from '@tanstack/react-query';

export type ExpenseReviewIncludeState = 'all' | 'included' | 'excluded';

export type ExpenseReviewSortBy =
  | 'account'
  | 'accountingPeriod'
  | 'aeProject'
  | 'amount'
  | 'financialDept'
  | 'fte'
  | 'fund'
  | 'sfn'
  | 'source';

export type ExpenseReviewSortDirection = 'asc' | 'desc';

export type ExpenseReviewCsvColumnId =
  | 'account'
  | 'accountingPeriod'
  | 'aeProject'
  | 'amount'
  | 'financialDept'
  | 'fte'
  | 'fund'
  | 'included'
  | 'sfn'
  | 'source';

export const EXPENSE_REVIEW_CSV_COLUMN_IDS: ExpenseReviewCsvColumnId[] = [
  'financialDept',
  'fund',
  'account',
  'aeProject',
  'accountingPeriod',
  'source',
  'sfn',
  'amount',
  'fte',
  'included',
];

export interface ExpenseReviewCodeName {
  code: string | null;
  name: string | null;
}

export interface ExpenseReviewTransaction {
  account: ExpenseReviewCodeName;
  accountingPeriod: string | null;
  aeProject: ExpenseReviewCodeName;
  amount: number | null;
  financialDept: ExpenseReviewCodeName;
  fte: number | null;
  fteIncluded: boolean;
  fund: ExpenseReviewCodeName;
  id: string;
  included: boolean;
  sfn: string | null;
  sfnLabel: string | null;
  source: 'AE' | 'UCP';
  sourceId: string;
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
  aeProjects: ExpenseReviewFilterOption[];
  financialDepts: ExpenseReviewFilterOption[];
  funds: ExpenseReviewFilterOption[];
  sfns: ExpenseReviewFilterOption[];
  sources: ExpenseReviewFilterOption[];
}

export interface ExpenseReviewFilters {
  account: string[];
  accountingPeriod: string[];
  aeProject: string[];
  financialDept: string[];
  fund: string[];
  sfn: string[];
  source: string[];
}

export interface ExpenseReviewTransactionsParams {
  filters: ExpenseReviewFilters;
  includeState: ExpenseReviewIncludeState;
  page: number;
  pageSize: number;
  sortBy?: ExpenseReviewSortBy;
  sortDirection?: ExpenseReviewSortDirection;
}

export interface ExpenseReviewTransactionsCsvParams {
  columns: ExpenseReviewCsvColumnId[];
  filters: ExpenseReviewFilters;
  includeState: ExpenseReviewIncludeState;
  sortBy?: ExpenseReviewSortBy;
  sortDirection?: ExpenseReviewSortDirection;
}

export const EMPTY_EXPENSE_REVIEW_FILTERS: ExpenseReviewFilters = {
  account: [],
  accountingPeriod: [],
  aeProject: [],
  financialDept: [],
  fund: [],
  sfn: [],
  source: [],
};

const filterQueryParams: Array<keyof ExpenseReviewFilters> = [
  'financialDept',
  'fund',
  'account',
  'aeProject',
  'accountingPeriod',
  'source',
  'sfn',
];

function appendParams(
  params: Omit<ExpenseReviewTransactionsParams, 'page' | 'pageSize'> &
    Partial<Pick<ExpenseReviewTransactionsParams, 'page' | 'pageSize'>>,
  includePagination: boolean
) {
  const search = new URLSearchParams({
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

  for (const column of params.columns) {
    search.append('column', column);
  }

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
