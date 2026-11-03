import { fetchJson } from '@/lib/api.ts';
import { keepPreviousData, queryOptions } from '@tanstack/react-query';

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
  totalAmount: number;
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
  includeZeroAmounts: boolean;
  page: number;
  pageSize: number;
  sortBy?: ExpenseReviewSortBy;
  sortDirection?: ExpenseReviewSortDirection;
}

export interface ExpenseReviewTransactionsCsvParams {
  displayByPeriod: boolean;
  filters: ExpenseReviewFilters;
  includeState: ExpenseReviewIncludeState;
  includeZeroAmounts: boolean;
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
    includeZeroAmounts: params.includeZeroAmounts ? 'true' : 'false',
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

  appendFilterParams(search, params.filters);

  return search;
}

function appendFilterParams(
  search: URLSearchParams,
  filters: ExpenseReviewFilters
) {
  for (const filter of filterQueryParams) {
    for (const value of filters[filter]) {
      search.append(filter, value);
    }
  }
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

// Each dropdown lists only values found in transactions matching the other
// selected filters, so the options are refetched whenever the filters change.
// The previous options stay on screen while the next ones load.
export const expenseReviewFilterOptionsQueryOptions = (
  filters: ExpenseReviewFilters
) =>
  queryOptions({
    placeholderData: keepPreviousData,
    queryFn: ({ signal }) => {
      const search = new URLSearchParams();
      appendFilterParams(search, filters);
      const query = search.toString();

      return fetchJson<ExpenseReviewFilterOptionsResponse>(
        query
          ? `/api/expensereview/filters?${query}`
          : '/api/expensereview/filters',
        {},
        signal
      );
    },
    queryKey: ['expenseReview', 'filters', filters],
  });
