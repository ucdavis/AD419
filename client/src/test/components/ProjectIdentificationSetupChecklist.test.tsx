import { ProjectIdentificationSetupChecklist } from '@/components/ProjectIdentificationSetupChecklist.tsx';
import {
  EMPTY_EXPENSE_REVIEW_FILTERS,
  expenseReviewFilterOptionsQueryOptions,
  type ExpenseReviewFilterOptionsResponse,
} from '@/queries/expenseReview.ts';
import type { ChecklistKind, ProjectIdentificationSetupResponse } from '@/queries/projectIdentification.ts';
import { createWorkflowSnapshot, server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';
import {
  isCancelledError,
  QueryClient,
  QueryClientProvider,
} from '@tanstack/react-query';
import { act, render, screen, waitFor } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';

const setup: ProjectIdentificationSetupResponse = {
  checklistItems: [
    {
      completed: true,
      hint: 'Set the reporting cycle',
      id: 'fiscal-period',
      kind: 'select',
      label: 'Confirm Fiscal Period',
      number: 1,
      ready: true,
      source: null,
      stale: false,
      staleReason: null,
      status: 'done',
    },
  ],
  completedCount: 1,
  cycleEnd: '2026-09-30',
  cycleStart: '2025-10-01',
  fiscalPeriodOptions: [
    {
      cycleEnd: '2025-09-30',
      cycleStart: '2024-10-01',
      fiscalYear: 'FY25',
      label: 'Oct 2024 - Sep 2025',
    },
    {
      cycleEnd: '2026-09-30',
      cycleStart: '2025-10-01',
      fiscalYear: 'FY26',
      label: 'Oct 2025 - Sep 2026',
    },
  ],
  fiscalYear: 'FY26',
  totalCount: 1,
  workflowRunId: 1,
};

const oldOptions: ExpenseReviewFilterOptionsResponse = {
  accountingPeriods: [],
  accounts: [],
  activities: [],
  aeProjects: [],
  entities: [],
  exclusionReasons: [],
  financialDepts: [],
  funds: [{ label: 'Previous cycle fund', value: 'OLD' }],
  programs: [],
  purposes: [],
  sfns: [],
  sources: [],
};

function renderChecklist(checklistSetup = setup) {
  const queryClient = new QueryClient({
    defaultOptions: { mutations: { retry: false }, queries: { retry: false } },
  });
  const view = render(
    <QueryClientProvider client={queryClient}>
      <ProjectIdentificationSetupChecklist issueCount={0} setup={checklistSetup} />
    </QueryClientProvider>
  );
  return { queryClient, ...view };
}

async function confirmFiscalYear(fiscalYear = setup.fiscalYear) {
  const user = userEvent.setup();
  await user.click(
    screen.getByRole('button', { name: /Confirm Fiscal Period/ })
  );
  await user.selectOptions(screen.getByLabelText('Fiscal year'), fiscalYear);
  await user.click(screen.getByRole('button', { name: 'Change' }));
}

describe('Fiscal confirmation Expense Review caches', () => {
  it.each(['FY25', 'FY26'])(
    'clears fresh caches and loads current options after confirming %s',
    async (fiscalYear) => {
      const period = setup.fiscalPeriodOptions.find(
        (option) => option.fiscalYear === fiscalYear
      )!;
      const currentOptions = {
        ...oldOptions,
        funds: [{ label: 'Current cycle fund', value: 'NEW' }],
      };
      let filterRequests = 0;
      server.use(
        http.put(
          '/api/projectidentification/fiscal-period',
          async ({ request }) => {
            expect(await request.json()).toEqual({ fiscalYear });
            return HttpResponse.json({ ...setup, ...period });
          }
        ),
        http.get('/api/user/me', () =>
          HttpResponse.json({ id: 'user-1', name: 'Shannon', roles: ['User'] })
        ),
        http.get('/api/workflow/snapshot', () =>
          HttpResponse.json({
            ...createWorkflowSnapshot({
              'data-classification': 'Complete',
              'data-import': 'Complete',
              'project-identification': 'Complete',
            }),
            ...period,
          })
        ),
        http.get('/api/expensereview/filters', () => {
          filterRequests += 1;
          return HttpResponse.json(currentOptions);
        })
      );
      const { queryClient, unmount } = renderChecklist();
      const options = expenseReviewFilterOptionsQueryOptions(
        EMPTY_EXPENSE_REVIEW_FILTERS
      );
      queryClient.setQueryData(options.queryKey, oldOptions);
      queryClient.setQueryData(
        expenseReviewFilterOptionsQueryOptions({
          ...EMPTY_EXPENSE_REVIEW_FILTERS,
          fund: ['OLD'],
        }).queryKey,
        oldOptions
      );
      queryClient.setQueryData(['expenseReview', 'transactions', {}], {
        fiscalYear: 'FY26',
      });
      queryClient.setQueryData(['unrelated'], 'keep');
      let review: ReturnType<typeof renderRoute> | undefined;
      try {
        await confirmFiscalYear(fiscalYear);
        await waitFor(() =>
          expect(
            queryClient.getQueriesData({ queryKey: ['expenseReview'] })
          ).toEqual([])
        );
        expect(queryClient.getQueryData(['unrelated'])).toBe('keep');
        unmount();
        review = renderRoute({
          initialPath: '/workflow/expense-review',
          queryClient,
        });
        await waitFor(() =>
          expect(screen.getByLabelText('Fund filter')).toBeEnabled()
        );
        await userEvent.setup().click(screen.getByLabelText('Fund filter'));
        expect(
          await screen.findByRole('option', { name: 'Current cycle fund' })
        ).toBeInTheDocument();
        expect(
          screen.queryByRole('option', { name: 'Previous cycle fund' })
        ).not.toBeInTheDocument();
        expect(filterRequests).toBe(1);
        expect(queryClient.getQueryData(options.queryKey)).toEqual(
          currentOptions
        );
      } finally {
        review?.cleanup();
        unmount();
        queryClient.clear();
      }
    }
  );

  it('retains cached data but marks it stale when confirmation fails', async () => {
    server.use(
      http.put('/api/projectidentification/fiscal-period', () =>
        HttpResponse.json({ detail: 'Confirmation failed' }, { status: 500 })
      )
    );
    const { queryClient, unmount } = renderChecklist();
    const options = expenseReviewFilterOptionsQueryOptions(
      EMPTY_EXPENSE_REVIEW_FILTERS
    );
    const transactionsKey = ['expenseReview', 'transactions', {}];
    const transactions = { fiscalYear: 'FY26' };
    queryClient.setQueryData(options.queryKey, oldOptions);
    queryClient.setQueryData(transactionsKey, transactions);
    try {
      await confirmFiscalYear('FY25');
      await waitFor(() =>
        expect(queryClient.getMutationCache().getAll()[0]?.state.status).toBe(
          'error'
        )
      );
      expect(queryClient.getQueryData(options.queryKey)).toBe(oldOptions);
      expect(queryClient.getQueryData(transactionsKey)).toBe(transactions);
      expect(queryClient.getQueryState(options.queryKey)?.isInvalidated).toBe(true);
      expect(queryClient.getQueryState(transactionsKey)?.isInvalidated).toBe(true);
    } finally {
      unmount();
      queryClient.clear();
    }
  });

  it('cancels a pending query and ignores its late result after confirmation', async () => {
    server.use(
      http.put('/api/projectidentification/fiscal-period', () =>
        HttpResponse.json(setup)
      )
    );
    const { queryClient, unmount } = renderChecklist();
    let complete!: (value: ExpenseReviewFilterOptionsResponse) => void;
    const response = new Promise<ExpenseReviewFilterOptionsResponse>(
      (resolve) => {
        complete = resolve;
      }
    );
    let signal: AbortSignal | undefined;
    const options = expenseReviewFilterOptionsQueryOptions(
      EMPTY_EXPENSE_REVIEW_FILTERS
    );
    const pending = queryClient
      .fetchQuery({
        ...options,
        queryFn: (context) => {
          signal = context.signal;
          return response;
        },
      })
      .catch((error: unknown) => error);
    try {
      await confirmFiscalYear();
      await waitFor(() => expect(signal?.aborted).toBe(true));
      expect(isCancelledError(await pending)).toBe(true);
      await act(async () => {
        complete(oldOptions);
        await response;
      });
      expect(queryClient.getQueryData(options.queryKey)).toBeUndefined();
      expect(
        queryClient.getQueriesData({ queryKey: ['expenseReview'] })
      ).toEqual([]);
    } finally {
      complete(oldOptions);
      unmount();
      queryClient.clear();
    }
  });
});

describe('project setup Expense Review invalidation', () => {
  it.each([
    { button: 'Finalize projects', kind: 'action', url: '/api/projectidentification/finalize' },
    { button: 'Re-import', kind: 'import', url: '/api/pgmprojects/import' },
  ] satisfies { button: string; kind: ChecklistKind; url: string }[])(
    'invalidates when $kind finishes after navigation, including partial failures',
    async ({ button, kind, url }) => {
      let finish!: () => void;
      const response = new Promise<void>((resolve) => { finish = resolve; });
      let start!: () => void;
      const started = new Promise<void>((resolve) => { start = resolve; });
      server.use(http.post(url, async () => {
        start();
        await response;
        return HttpResponse.json({ detail: 'Recording failed' }, { status: 500 });
      }));
      const { queryClient, unmount } = renderChecklist({
        ...setup,
        checklistItems: [{ ...setup.checklistItems[0], completed: false, kind }],
      });
      const key = expenseReviewFilterOptionsQueryOptions(EMPTY_EXPENSE_REVIEW_FILTERS).queryKey;
      queryClient.setQueryData(key, oldOptions);
      try {
        await userEvent.setup().click(screen.getByRole('button', { name: button }));
        await started;
        unmount();
        finish();
        await waitFor(() => expect(queryClient.getMutationCache().getAll()[0]?.state.status).toBe('error'));
        expect(queryClient.getQueryState(key)?.isInvalidated).toBe(true);
        expect(queryClient.getQueryData(key)).toBe(oldOptions);
      } finally {
        finish();
        unmount();
        queryClient.clear();
      }
    }
  );
});
