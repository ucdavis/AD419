import {
  EMPTY_EXPENSE_REVIEW_FILTERS,
  expenseReviewFilterOptionsQueryOptions,
  expenseReviewTransactionsQueryOptions,
  invalidateExpenseReviewQueries,
  type ExpenseReviewFilterOptionsResponse,
} from '@/queries/expenseReview.ts';
import { useUpdateSegmentClassification } from '@/queries/segmentClassifications.ts';
import { WORKFLOW_SNAPSHOT_KEY } from '@/queries.ts';
import { server } from '@/test/mswUtils.ts';
import {
  QueryClient,
  QueryClientProvider,
  QueryObserver,
} from '@tanstack/react-query';
import { act, renderHook, waitFor } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import type { ReactNode } from 'react';
import { describe, expect, it, vi } from 'vitest';

const initialOptions: ExpenseReviewFilterOptionsResponse = {
  accountingPeriods: [],
  accounts: [],
  activities: [],
  aeProjects: [],
  entities: [],
  exclusionReasons: [],
  financialDepts: [],
  funds: [{ label: 'Original fund', value: 'OLD' }],
  programs: [],
  purposes: [],
  sfns: [],
  sources: [],
};

const updatedOptions: ExpenseReviewFilterOptionsResponse = {
  ...initialOptions,
  funds: [{ label: 'Updated fund', value: 'NEW' }],
};

function completion<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

function client() {
  return new QueryClient({
    defaultOptions: { mutations: { retry: false }, queries: { retry: false } },
  });
}

describe('expense review query invalidation', () => {
  it('retains inactive cached data and marks it stale without fetching after repeated edits', async () => {
    const queryClient = client();
    const queryFn = vi.fn(async () => initialOptions);
    const options = {
      ...expenseReviewFilterOptionsQueryOptions(EMPTY_EXPENSE_REVIEW_FILTERS),
      queryFn,
    };
    await queryClient.fetchQuery(options);
    queryClient.setQueryData(['unrelated'], 'keep');
    try {
      for (let edit = 0; edit < 3; edit += 1) {
        await invalidateExpenseReviewQueries(queryClient);
      }
      expect(queryFn).toHaveBeenCalledTimes(1);
      expect(queryClient.getQueryData(options.queryKey)).toBe(initialOptions);
      expect(queryClient.getQueryState(options.queryKey)?.isInvalidated).toBe(true);
      expect(queryClient.getQueryData(['unrelated'])).toBe('keep');
    } finally {
      queryClient.clear();
    }
  });

  it('refreshes active queries while retaining displayed data until the new response arrives', async () => {
    const queryClient = client();
    const response = completion<ExpenseReviewFilterOptionsResponse>();
    const options = expenseReviewFilterOptionsQueryOptions(EMPTY_EXPENSE_REVIEW_FILTERS);
    queryClient.setQueryData(options.queryKey, initialOptions);
    const queryFn = vi.fn(() => response.promise);
    const observer = new QueryObserver(queryClient, {
      ...options,
      queryFn,
      refetchOnMount: false,
    });
    const unsubscribe = observer.subscribe(() => {});
    try {
      const invalidation = invalidateExpenseReviewQueries(queryClient);
      await waitFor(() => expect(queryFn).toHaveBeenCalledTimes(1));
      expect(observer.getCurrentResult().data).toBe(initialOptions);
      expect(observer.getCurrentResult().isFetching).toBe(true);
      response.resolve(updatedOptions);
      await invalidation;
      expect(queryClient.getQueryData(options.queryKey)).toEqual(updatedOptions);
      expect(queryClient.getQueryState(options.queryKey)?.isInvalidated).toBe(false);
    } finally {
      response.resolve(updatedOptions);
      unsubscribe();
      queryClient.clear();
    }
  });

  it('cancels an outstanding response before refreshing so it cannot overwrite newer data', async () => {
    const queryClient = client();
    const obsolete = completion<ExpenseReviewFilterOptionsResponse>();
    const options = expenseReviewFilterOptionsQueryOptions(EMPTY_EXPENSE_REVIEW_FILTERS);
    let oldSignal: AbortSignal | undefined;
    let calls = 0;
    const observer = new QueryObserver(queryClient, {
      ...options,
      queryFn: ({ signal }) => {
        calls += 1;
        if (calls === 1) {
          oldSignal = signal;
          return obsolete.promise;
        }
        return Promise.resolve(updatedOptions);
      },
    });
    const unsubscribe = observer.subscribe(() => {});
    try {
      expect(calls).toBe(1);
      await invalidateExpenseReviewQueries(queryClient);
      expect(oldSignal?.aborted).toBe(true);
      expect(calls).toBe(2);
      expect(queryClient.getQueryData(options.queryKey)).toEqual(updatedOptions);
      obsolete.resolve(initialOptions);
      await obsolete.promise;
      expect(queryClient.getQueryData(options.queryKey)).toEqual(updatedOptions);
    } finally {
      obsolete.resolve(initialOptions);
      unsubscribe();
      queryClient.clear();
    }
  });

  it('checks both filters and transactions on every mount even while cached data is fresh', async () => {
    const queryClient = client();
    const filterOptions = expenseReviewFilterOptionsQueryOptions(EMPTY_EXPENSE_REVIEW_FILTERS);
    const transactionOptions = expenseReviewTransactionsQueryOptions({
      displayByPeriod: true,
      filters: EMPTY_EXPENSE_REVIEW_FILTERS,
      includeState: 'included',
      includeZeroAmounts: true,
      page: 2,
      pageSize: 50,
      sortBy: 'amount',
      sortDirection: 'desc',
    });
    try {
      for (const options of [filterOptions, transactionOptions]) {
        const queryKey = [...options.queryKey];
        const refetchOnMount = options.refetchOnMount;
        if (refetchOnMount !== 'always') {
          throw new Error('Expense review must refresh on every mount.');
        }
        const queryFn = vi.fn(async () => 'current');
        queryClient.setQueryData(queryKey, 'cached');
        const observer = new QueryObserver(queryClient, {
          queryFn,
          queryKey,
          refetchOnMount,
          staleTime: 60_000,
        });
        const unsubscribe = observer.subscribe(() => {});
        await waitFor(() => expect(observer.getCurrentResult().isFetching).toBe(false));
        expect(queryFn).toHaveBeenCalledTimes(1);
        unsubscribe();
        const unsubscribeAgain = observer.subscribe(() => {});
        await waitFor(() => expect(observer.getCurrentResult().isFetching).toBe(false));
        expect(queryFn).toHaveBeenCalledTimes(2);
        unsubscribeAgain();
      }
    } finally {
      queryClient.clear();
    }
  });
});

describe('classification invalidation', () => {
  const buildKey = ['autoAssociations', 'build'] as const;
  const reportKey = ['autoAssociations', 'fte'] as const;
  const employeeKey = [
    'expenseReview',
    'details',
    { buildId: 1, employeeId: 'E1', kind: 'employee' },
  ] as const;
  const groupKey = [
    'expenseReview', 'details', { groupId: 'G1', kind: 'group' },
  ] as const;
  const transactionKey = ['expenseReview', 'transactions'] as const;

  it.each([
    { fails: false, segmentType: 'Fund' as const },
    { fails: true, segmentType: 'Fund' as const },
    { fails: false, segmentType: 'Ern' as const },
    { fails: true, segmentType: 'Ern' as const },
  ])('resets built data after navigation ($segmentType, failure: $fails)', async ({ fails, segmentType }) => {
    const queryClient = client();
    const started = completion<void>();
    const response = completion<void>();
    server.use(http.patch('/api/segmentclassifications', async () => {
      started.resolve();
      await response.promise;
      return fails
        ? HttpResponse.json({ detail: 'Failed after saving' }, { status: 500 })
        : new HttpResponse(null, { status: 204 });
    }));
    const key = expenseReviewFilterOptionsQueryOptions(EMPTY_EXPENSE_REVIEW_FILTERS).queryKey;
    queryClient.setQueryData(key, initialOptions);
    for (const queryKey of [
      buildKey, reportKey, employeeKey, groupKey, transactionKey, WORKFLOW_SNAPSHOT_KEY,
    ]) {
      queryClient.setQueryData(queryKey, 'cached');
    }
    const { result, unmount } = renderHook(useUpdateSegmentClassification, {
      wrapper: ({ children }: { children: ReactNode }) => (
        <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
      ),
    });
    try {
      act(() => {
        result.current.mutate({
          code: 'OLD',
          includeInReport: true,
          segmentType,
          sfn: segmentType === 'Fund' ? '220' : null,
        });
      });
      await started.promise;
      unmount();
      response.resolve();
      await waitFor(() =>
        expect(queryClient.getMutationCache().getAll()[0]?.state.status).toBe(
          fails ? 'error' : 'success'
        )
      );
      expect(queryClient.getQueryState(key)?.isInvalidated).toBe(segmentType !== 'Ern');
      expect(queryClient.getQueryData(key)).toBe(initialOptions);
      for (const queryKey of [buildKey, reportKey, employeeKey]) {
        expect(queryClient.getQueryData(queryKey)).toBeUndefined();
        expect(queryClient.getQueryState(queryKey)?.fetchStatus).toBe('idle');
      }
      for (const queryKey of [groupKey, transactionKey]) {
        expect(queryClient.getQueryData(queryKey)).toBe('cached');
        expect(queryClient.getQueryState(queryKey)?.isInvalidated).toBe(segmentType !== 'Ern');
      }
      expect(queryClient.getQueryState(WORKFLOW_SNAPSHOT_KEY)?.isInvalidated).toBe(true);
    } finally {
      response.resolve();
      unmount();
      queryClient.clear();
    }
  });

  it.each([
    { fails: false, queryKey: buildKey, segmentType: 'Ern' as const },
    { fails: true, queryKey: buildKey, segmentType: 'Ern' as const },
    { fails: false, queryKey: employeeKey, segmentType: 'Ern' as const },
    { fails: true, queryKey: employeeKey, segmentType: 'Ern' as const },
    { fails: false, queryKey: employeeKey, segmentType: 'Fund' as const },
    { fails: true, queryKey: employeeKey, segmentType: 'Fund' as const },
    { fails: false, queryKey: WORKFLOW_SNAPSHOT_KEY, segmentType: 'Ern' as const },
    { fails: true, queryKey: WORKFLOW_SNAPSHOT_KEY, segmentType: 'Ern' as const },
  ])('replaces outstanding queries and awaits refresh ($segmentType, failure: $fails, key: $queryKey)', async ({ fails, queryKey, segmentType }) => {
    const queryClient = client();
    const obsolete = completion<string>();
    const fresh = completion<string>();
    const refreshStarted = completion<void>();
    let oldSignal: AbortSignal | undefined;
    let calls = 0;
    // Exercise a workflow snapshot's very first request as well as cached reports.
    if (queryKey !== WORKFLOW_SNAPSHOT_KEY) {
      queryClient.setQueryData(queryKey, 'cached');
    }
    const observer = new QueryObserver(queryClient, {
      queryFn: ({ signal }) => {
        calls += 1;
        if (calls === 1) {
          oldSignal = signal;
          return obsolete.promise;
        }
        refreshStarted.resolve();
        return fresh.promise;
      },
      queryKey,
    });
    const unsubscribe = observer.subscribe(() => {});
    server.use(http.patch('/api/segmentclassifications', () =>
      fails
        ? HttpResponse.text('Save failed after reset.', { status: 500 })
        : new HttpResponse(null, { status: 204 })
    ));
    const { result, unmount } = renderHook(useUpdateSegmentClassification, {
      wrapper: ({ children }: { children: ReactNode }) => (
        <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
      ),
    });
    try {
      act(() => {
        result.current.mutate({
          code: 'REG',
          includeInReport: true,
          segmentType,
          sfn: segmentType === 'Fund' ? '220' : null,
        });
      });
      await refreshStarted.promise;
      expect(oldSignal?.aborted).toBe(true);
      expect(observer.getCurrentResult().data).toBeUndefined();
      expect(observer.getCurrentResult().isFetching).toBe(true);
      await waitFor(() => expect(result.current.isPending).toBe(true));
      obsolete.resolve('obsolete');
      await obsolete.promise;
      expect(queryClient.getQueryData(queryKey)).toBeUndefined();
      fresh.resolve('current');
      await waitFor(() =>
        expect(result.current.status).toBe(fails ? 'error' : 'success')
      );
      expect(calls).toBe(2);
      expect(queryClient.getQueryData(queryKey)).toBe('current');
    } finally {
      obsolete.resolve('obsolete');
      fresh.resolve('current');
      unsubscribe();
      unmount();
      queryClient.clear();
    }
  });
});
