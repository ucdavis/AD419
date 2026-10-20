import { describe, expect, it } from 'vitest';
import {
  filtersToSearch,
  parseExpenseReviewSearch,
  resolveExpenseReviewView,
} from '@/components/expenseReview/expenseReviewSearch.ts';
import { EMPTY_EXPENSE_REVIEW_FILTERS } from '@/queries/expenseReview.ts';

describe('expense review search params', () => {
  it('resolves defaults from an empty search', () => {
    const view = resolveExpenseReviewView(parseExpenseReviewSearch({}));

    expect(view).toEqual({
      displayByPeriod: false,
      filters: EMPTY_EXPENSE_REVIEW_FILTERS,
      includeState: 'all',
      includeZeroAmounts: false,
      page: 1,
      pageSize: 25,
      sortBy: 'source',
      sortDirection: 'asc',
    });
  });

  it('round-trips every field', () => {
    const search = parseExpenseReviewSearch({
      byPeriod: true,
      dir: 'desc',
      fund: ['13U02', '12345'],
      include: 'excluded',
      page: 3,
      size: 50,
      sort: 'amount',
      source: ['AE'],
      zero: true,
    });
    const view = resolveExpenseReviewView(search);

    expect(view.displayByPeriod).toBe(true);
    expect(view.sortDirection).toBe('desc');
    expect(view.filters.fund).toEqual(['13U02', '12345']);
    expect(view.filters.source).toEqual(['AE']);
    expect(view.includeState).toBe('excluded');
    expect(view.page).toBe(3);
    expect(view.pageSize).toBe(50);
    expect(view.sortBy).toBe('amount');
    expect(view.includeZeroAmounts).toBe(true);
  });

  it('drops invalid values instead of throwing', () => {
    const search = parseExpenseReviewSearch({
      fund: 'not-an-array',
      include: 'maybe',
      page: 0,
      size: 33,
      sort: 'nope',
    });

    expect(search).toEqual({});
    expect(resolveExpenseReviewView(search).pageSize).toBe(25);
  });

  it('turns filters into a minimal search patch', () => {
    const patch = filtersToSearch(
      { ...EMPTY_EXPENSE_REVIEW_FILTERS, fund: ['13U02'] },
      'all'
    );

    expect(patch).toEqual({
      account: undefined,
      accountingPeriod: undefined,
      activity: undefined,
      aeProject: undefined,
      entity: undefined,
      exclusionReason: undefined,
      financialDept: undefined,
      fund: ['13U02'],
      include: undefined,
      page: undefined,
      program: undefined,
      purpose: undefined,
      sfn: undefined,
      source: undefined,
    });
    expect(
      filtersToSearch(EMPTY_EXPENSE_REVIEW_FILTERS, 'included').include
    ).toBe('included');
  });
});
