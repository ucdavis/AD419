import { describe, expect, it, vi } from 'vitest';
import { buildExpenseReviewClientTools } from '@/components/expenseReview/expenseReviewAssistantTools.ts';
import type { ExpenseReviewSearch } from '@/components/expenseReview/expenseReviewSearch.ts';
import { EMPTY_EXPENSE_REVIEW_FILTERS } from '@/queries/expenseReview.ts';

function host(search: ExpenseReviewSearch = {}) {
  const setSearch = vi.fn();
  const tools = buildExpenseReviewClientTools({
    getSearch: () => search,
    setSearch,
  });
  const tool = (name: string) => {
    const found = tools.find((candidate) => candidate.name === name);
    if (!found) {
      throw new Error(`missing tool ${name}`);
    }
    return found;
  };
  return { setSearch, tool };
}

describe('expense review client tools', () => {
  it.each([false, true])(
    'get_expense_review_view reports loadAll: %s',
    (loadAll) => {
      const { tool } = host({
        fund: ['13U02'],
        include: 'excluded',
        loadAll,
        page: 2,
      });

      expect(tool('get_expense_review_view').execute({})).toEqual({
        displayByPeriod: false,
        filters: { ...EMPTY_EXPENSE_REVIEW_FILTERS, fund: ['13U02'] },
        includeState: 'excluded',
        includeZeroAmounts: false,
        loadAll,
        page: 2,
        pageSize: 25,
        sortBy: 'source',
        sortDirection: 'asc',
      });
    }
  );

  it('set_expense_review_filters replaces filters, resets the page, and reports what it applied', () => {
    const { setSearch, tool } = host({
      fund: ['13U02'],
      loadAll: true,
      page: 3,
      source: ['AE'],
    });

    const result = tool('set_expense_review_filters').execute({
      account: ['770000'],
      includeState: 'excluded',
    });

    expect(setSearch).toHaveBeenCalledWith({
      account: ['770000'],
      accountingPeriod: undefined,
      activity: undefined,
      aeProject: undefined,
      entity: undefined,
      exclusionReason: undefined,
      financialDept: undefined,
      fund: undefined,
      include: 'excluded',
      loadAll: undefined,
      page: undefined,
      program: undefined,
      purpose: undefined,
      sfn: undefined,
      source: undefined,
    });
    expect(result).toEqual({
      applied: true,
      filters: { ...EMPTY_EXPENSE_REVIEW_FILTERS, account: ['770000'] },
      includeState: 'excluded',
      loadAll: false,
    });
  });

  it('explicitly loads all expenses and clears previous filters and pagination', () => {
    const { setSearch, tool } = host({
      fund: ['13U02'],
      include: 'excluded',
      page: 3,
      source: ['AE'],
    });

    expect(
      tool('set_expense_review_filters').execute({
        includeState: 'all',
        loadAll: true,
      })
    ).toEqual({
      applied: true,
      filters: EMPTY_EXPENSE_REVIEW_FILTERS,
      includeState: 'all',
      loadAll: true,
    });
    expect(setSearch).toHaveBeenCalledWith(
      expect.objectContaining({
        fund: undefined,
        include: undefined,
        loadAll: true,
        page: undefined,
        source: undefined,
      })
    );
  });

  it.each([undefined, false])(
    'clears explicit loading with loadAll: %s',
    (loadAll) => {
      const { setSearch, tool } = host({ loadAll: true });

      expect(
        tool('set_expense_review_filters').execute(
          loadAll === undefined ? {} : { loadAll }
        )
      ).toEqual({
        applied: true,
        filters: EMPTY_EXPENSE_REVIEW_FILTERS,
        includeState: 'all',
        loadAll: false,
      });
      expect(setSearch).toHaveBeenCalledWith(
        expect.objectContaining({ loadAll: undefined })
      );
    }
  );

  it('set_expense_review_filters treats a missing include state as all', () => {
    const { tool } = host();

    expect(
      tool('set_expense_review_filters').execute({ fund: ['1'] })
    ).toMatchObject({
      includeState: 'all',
    });
  });
});
