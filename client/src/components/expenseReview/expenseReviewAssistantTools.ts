import {
  filtersToSearch,
  resolveExpenseReviewView,
  type ExpenseReviewSearch,
} from '@/components/expenseReview/expenseReviewSearch.ts';
import {
  EMPTY_EXPENSE_REVIEW_FILTERS,
  type ExpenseReviewFilters,
  type ExpenseReviewIncludeState,
} from '@/queries/expenseReview.ts';
import type { AssistantClientTool } from '@ucdavis/caes-ai-assistant-react';

export interface ExpenseReviewToolHost {
  getSearch: () => ExpenseReviewSearch;
  setSearch: (patch: ExpenseReviewSearch) => void;
}

interface SetFiltersArgs extends Partial<ExpenseReviewFilters> {
  includeState?: ExpenseReviewIncludeState;
}

const FILTER_KEYS = Object.keys(
  EMPTY_EXPENSE_REVIEW_FILTERS
) as Array<keyof ExpenseReviewFilters>;

function toFilters(args: SetFiltersArgs): ExpenseReviewFilters {
  const filters = { ...EMPTY_EXPENSE_REVIEW_FILTERS };
  for (const key of FILTER_KEYS) {
    filters[key] = Array.isArray(args[key]) ? [...args[key]!] : [];
  }
  return filters;
}

export function buildExpenseReviewClientTools(
  host: ExpenseReviewToolHost
): AssistantClientTool[] {
  return [
    {
      execute: () => resolveExpenseReviewView(host.getSearch()),
      name: 'get_expense_review_view',
    },
    {
      execute: (args: unknown) => {
        const input = (args ?? {}) as SetFiltersArgs;
        const filters = toFilters(input);
        const includeState = input.includeState ?? 'all';
        host.setSearch(filtersToSearch(filters, includeState));
        return { applied: true, filters, includeState };
      },
      name: 'set_expense_review_filters',
    },
  ];
}
