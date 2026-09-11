import {
  EMPTY_EXPENSE_REVIEW_FILTERS,
  type ExpenseReviewFilters,
  type ExpenseReviewIncludeState,
  type ExpenseReviewSortBy,
  type ExpenseReviewSortDirection,
} from '@/queries/expenseReview.ts';
import { z } from 'zod';

export const EXPENSE_REVIEW_PAGE_SIZES = [10, 25, 50, 100] as const;

const SORT_FIELDS = [
  'account',
  'accountingPeriod',
  'activity',
  'aeProject',
  'amount',
  'entity',
  'financialDept',
  'fund',
  'included',
  'program',
  'purpose',
  'sfn',
  'source',
] as const satisfies readonly ExpenseReviewSortBy[];

// Wrapped in a helper so the `.catch()` call is not a top-level call
// expression (avoids a false-positive unicorn/prefer-top-level-await lint
// error, which treats any top-level `.catch(...)` call as a promise chain).
function lenient<T extends z.ZodTypeAny>(schema: T) {
  return schema.optional().catch(undefined);
}

const list = lenient(z.array(z.string()));

export const expenseReviewSearchSchema = z.object({
  account: list,
  accountingPeriod: list,
  activity: list,
  aeProject: list,
  byPeriod: lenient(z.boolean()),
  dir: lenient(z.enum(['asc', 'desc'])),
  entity: list,
  exclusionReason: list,
  financialDept: list,
  fund: list,
  include: lenient(z.enum(['all', 'included', 'excluded'])),
  page: lenient(z.number().int().min(1)),
  program: list,
  purpose: list,
  sfn: list,
  size: lenient(
    z.union([z.literal(10), z.literal(25), z.literal(50), z.literal(100)])
  ),
  sort: lenient(z.enum(SORT_FIELDS)),
  source: list,
  zero: lenient(z.boolean()),
});

export type ExpenseReviewSearch = z.infer<typeof expenseReviewSearchSchema>;

export interface ExpenseReviewView {
  displayByPeriod: boolean;
  filters: ExpenseReviewFilters;
  includeState: ExpenseReviewIncludeState;
  includeZeroAmounts: boolean;
  page: number;
  pageSize: number;
  sortBy: ExpenseReviewSortBy;
  sortDirection: ExpenseReviewSortDirection;
}

const FILTER_KEYS = Object.keys(
  EMPTY_EXPENSE_REVIEW_FILTERS
) as Array<keyof ExpenseReviewFilters>;

function stripUndefined(search: ExpenseReviewSearch): ExpenseReviewSearch {
  return Object.fromEntries(
    Object.entries(search).filter(([, value]) => value !== undefined)
  ) as ExpenseReviewSearch;
}

export function parseExpenseReviewSearch(input: unknown): ExpenseReviewSearch {
  const result = expenseReviewSearchSchema.safeParse(input ?? {});
  return result.success ? stripUndefined(result.data) : {};
}

export function resolveExpenseReviewView(
  search: ExpenseReviewSearch
): ExpenseReviewView {
  const filters = { ...EMPTY_EXPENSE_REVIEW_FILTERS };
  for (const key of FILTER_KEYS) {
    filters[key] = search[key] ?? [];
  }

  return {
    displayByPeriod: search.byPeriod ?? false,
    filters,
    includeState: search.include ?? 'all',
    includeZeroAmounts: search.zero ?? false,
    page: search.page ?? 1,
    pageSize: search.size ?? 25,
    sortBy: search.sort ?? 'source',
    sortDirection: search.dir ?? 'asc',
  };
}

export function filtersToSearch(
  filters: ExpenseReviewFilters,
  includeState: ExpenseReviewIncludeState
): ExpenseReviewSearch {
  const patch: ExpenseReviewSearch = {
    include: includeState === 'all' ? undefined : includeState,
    page: undefined,
  };
  for (const key of FILTER_KEYS) {
    patch[key] = filters[key].length > 0 ? filters[key] : undefined;
  }

  return patch;
}
