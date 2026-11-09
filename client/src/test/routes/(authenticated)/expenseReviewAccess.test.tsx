import { WORKFLOW_SNAPSHOT_KEY } from '@/queries.ts';
import { createWorkflowSnapshot, server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';
import { QueryClient } from '@tanstack/react-query';
import { act, screen, waitFor } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('@/components/expenseReview/ExpenseReviewAssistant.tsx', () => ({
  ExpenseReviewAssistant: () => <input aria-label="Assistant draft" />,
}));

const snapshot = createWorkflowSnapshot({
  'data-classification': 'Complete',
  'data-import': 'Complete',
  'expense-review': 'InProgress',
  'project-identification': 'Complete',
});
const lockedSnapshot = createWorkflowSnapshot({
  'data-classification': 'InProgress',
  'data-import': 'Complete',
  'project-identification': 'Complete',
});

function mockReview() {
  const filterRequests = vi.fn();
  const transactionRequests = vi.fn();
  const workflowRequests = vi.fn();
  const importStatusRequests = vi.fn();
  server.use(
    http.get('/api/user/me', () =>
      HttpResponse.json({
        email: 'shannon@example.edu',
        id: 'user-1',
        name: 'Shannon',
        roles: ['User'],
      })
    ),
    http.get('/api/workflow/snapshot', () => {
      workflowRequests();
      return HttpResponse.json(snapshot);
    }),
    http.get('/api/workflow/documentation', () => HttpResponse.json({})),
    http.get('/api/segmentclassifications', () => HttpResponse.json([])),
    http.get('/api/importruns/current', () => {
      importStatusRequests();
      return new HttpResponse(null, { status: 503 });
    }),
    http.get('/api/expensereview/filters', () => {
      filterRequests();
      return HttpResponse.json({
        accountingPeriods: [],
        accounts: [],
        activities: [],
        aeProjects: [],
        entities: [],
        exclusionReasons: [],
        financialDepts: [],
        funds: [],
        programs: [],
        purposes: [],
        sfns: [],
        sources: [],
      });
    }),
    http.get('/api/expensereview/transactions', () => {
      transactionRequests();
      return HttpResponse.json({
        counts: { all: 0, excluded: 0, included: 0 },
        cycleEnd: snapshot.cycleEnd,
        cycleStart: snapshot.cycleStart,
        fiscalYear: snapshot.fiscalYear,
        page: 1,
        pageCount: 0,
        pageSize: 25,
        rows: [],
        totalAmount: 0,
        totalCount: 0,
      });
    })
  );
  return {
    filterRequests,
    importStatusRequests,
    transactionRequests,
    workflowRequests,
  };
}

function expectReviewBlocked(requests: ReturnType<typeof mockReview>) {
  expect(requests.filterRequests).not.toHaveBeenCalled();
  expect(requests.transactionRequests).not.toHaveBeenCalled();
  expect(
    screen.queryByRole('button', { name: 'Export CSV' })
  ).not.toBeInTheDocument();
  expect(
    screen.queryByRole('button', { name: 'Ask CAES AI' })
  ).not.toBeInTheDocument();
}

describe('Expense Review workflow access', () => {
  beforeEach(() => {
    vi.stubGlobal('matchMedia', () => ({
      addEventListener: vi.fn(),
      matches: true,
      removeEventListener: vi.fn(),
    }));
  });
  afterEach(() => vi.unstubAllGlobals());

  it.each([false, true])(
    'checks fresh access before mounting review, accessible: %s',
    async (accessible) => {
      const requests = mockReview();
      const started = Promise.withResolvers<void>();
      const response = Promise.withResolvers<typeof snapshot>();
      const queryClient = new QueryClient({
        defaultOptions: { queries: { retry: false, staleTime: Infinity } },
      });
      queryClient.setQueryData(WORKFLOW_SNAPSHOT_KEY, snapshot);
      server.use(
        http.get('/api/workflow/snapshot', async () => {
          started.resolve();
          return HttpResponse.json(await response.promise);
        })
      );
      const { cleanup, router } = renderRoute({
        initialPath: '/workflow/expense-review?include=excluded',
        queryClient,
      });
      try {
        await started.promise;
        expectReviewBlocked(requests);
        await act(async () => {
          response.resolve(accessible ? snapshot : lockedSnapshot);
        });
        if (accessible) {
          await screen.findByRole('button', { name: 'Export CSV' });
          expect(requests.filterRequests).toHaveBeenCalledTimes(1);
          expect(requests.transactionRequests).toHaveBeenCalledTimes(1);
        } else {
          await waitFor(() =>
            expect(router.state.location.pathname).toBe(
              '/workflow/data-classification'
            )
          );
          expectReviewBlocked(requests);
        }
        expect(requests.importStatusRequests).not.toHaveBeenCalled();
      } finally {
        response.resolve(snapshot);
        cleanup();
      }
    }
  );

  it('blocks entry on a failed check despite cached access, then retries', async () => {
    const requests = mockReview();
    const queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    });
    queryClient.setQueryData(WORKFLOW_SNAPSHOT_KEY, snapshot);
    server.use(
      http.get(
        '/api/workflow/snapshot',
        () => new HttpResponse(null, { status: 503 })
      )
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?include=excluded',
      queryClient,
    });
    try {
      expect(await screen.findByRole('alert')).toHaveTextContent(
        'Unable to load workflow status'
      );
      expectReviewBlocked(requests);
      server.use(
        http.get('/api/workflow/snapshot', () => HttpResponse.json(snapshot))
      );
      await userEvent
        .setup()
        .click(screen.getByRole('button', { name: 'Retry' }));
      await screen.findByRole('button', { name: 'Export CSV' });
      expect(screen.queryByRole('alert')).not.toBeInTheDocument();
      expect(requests.importStatusRequests).not.toHaveBeenCalled();
    } finally {
      cleanup();
    }
  });

  it('preserves the assistant through search changes and failed background workflow refreshes', async () => {
    const requests = mockReview();
    const { cleanup, queryClient, router } = renderRoute({
      initialPath: '/workflow/expense-review?include=excluded',
    });
    try {
      await screen.findByRole('button', { name: 'Export CSV' });
      const user = userEvent.setup();
      await user.click(screen.getByRole('button', { name: 'Ask CAES AI' }));
      const draft = screen.getByRole('textbox', { name: 'Assistant draft' });
      await user.type(draft, 'Explain these expenses');
      expect(requests.workflowRequests).toHaveBeenCalledTimes(1);

      await act(() =>
        router.navigate({
          params: { stageId: 'expense-review' },
          search: {
            fund: ['F1'],
            include: 'excluded',
            page: 2,
            size: 50,
            sort: 'amount',
          },
          to: '/workflow/$stageId',
        })
      );
      expect(requests.workflowRequests).toHaveBeenCalledTimes(1);
      expect(screen.getByRole('textbox', { name: 'Assistant draft' })).toBe(
        draft
      );
      expect(draft).toHaveValue('Explain these expenses');

      server.use(
        http.get(
          '/api/workflow/snapshot',
          () => new HttpResponse(null, { status: 503 })
        )
      );
      await act(() =>
        queryClient.refetchQueries({ queryKey: WORKFLOW_SNAPSHOT_KEY })
      );
      expect(queryClient.getQueryState(WORKFLOW_SNAPSHOT_KEY)?.status).toBe(
        'error'
      );
      expect(screen.getByRole('textbox', { name: 'Assistant draft' })).toBe(
        draft
      );
      expect(draft).toHaveValue('Explain these expenses');
      expect(
        screen.getByRole('button', { name: 'Export CSV' })
      ).toBeInTheDocument();
      expect(requests.importStatusRequests).not.toHaveBeenCalled();
    } finally {
      cleanup();
    }
  });

  it.each(['/about', '/workflow/data-classification'])(
    'checks access again after returning from %s',
    async (destination) => {
      const requests = mockReview();
      const started = Promise.withResolvers<void>();
      const response = Promise.withResolvers<typeof snapshot>();
      const { cleanup, router } = renderRoute({
        initialPath: '/workflow/expense-review?include=excluded',
      });
      try {
        await screen.findByRole('button', { name: 'Export CSV' });
        await act(() => router.navigate({ to: destination }));
        const previousChecks = requests.workflowRequests.mock.calls.length;
        await act(() =>
          router.preloadRoute({
            params: { stageId: 'expense-review' },
            to: '/workflow/$stageId',
          })
        );
        expect(requests.workflowRequests).toHaveBeenCalledTimes(previousChecks);

        server.use(
          http.get('/api/workflow/snapshot', async () => {
            requests.workflowRequests();
            started.resolve();
            return HttpResponse.json(await response.promise);
          })
        );
        let navigation: Promise<void>;
        act(() => {
          navigation = router.navigate({
            params: { stageId: 'expense-review' },
            search: { include: 'excluded' },
            to: '/workflow/$stageId',
          });
        });
        await started.promise;
        expect(requests.transactionRequests).toHaveBeenCalledTimes(1);
        expect(requests.filterRequests).toHaveBeenCalledTimes(1);
        await act(async () => {
          response.resolve(snapshot);
          await navigation;
        });
        await screen.findByRole('button', { name: 'Export CSV' });
        expect(requests.workflowRequests).toHaveBeenCalledTimes(
          previousChecks + 1
        );
        await waitFor(() =>
          expect(requests.transactionRequests).toHaveBeenCalledTimes(2)
        );
        expect(requests.importStatusRequests).not.toHaveBeenCalled();
      } finally {
        response.resolve(snapshot);
        cleanup();
      }
    }
  );

  it('redirects when a successful background snapshot revokes access', async () => {
    const requests = mockReview();
    const { cleanup, queryClient, router } = renderRoute({
      initialPath: '/workflow/expense-review?include=excluded',
    });
    try {
      await screen.findByRole('button', { name: 'Export CSV' });
      await userEvent
        .setup()
        .click(screen.getByRole('button', { name: 'Ask CAES AI' }));
      expect(
        screen.getByRole('textbox', { name: 'Assistant draft' })
      ).toBeInTheDocument();
      server.use(
        http.get('/api/workflow/snapshot', () =>
          HttpResponse.json(lockedSnapshot)
        )
      );
      await act(() =>
        queryClient.refetchQueries({ queryKey: WORKFLOW_SNAPSHOT_KEY })
      );
      await waitFor(() =>
        expect(router.state.location.pathname).toBe(
          '/workflow/data-classification'
        )
      );
      expect(
        screen.queryByRole('textbox', { name: 'Assistant draft' })
      ).not.toBeInTheDocument();
      expect(
        screen.queryByRole('button', { name: 'Export CSV' })
      ).not.toBeInTheDocument();
      expect(requests.importStatusRequests).not.toHaveBeenCalled();
    } finally {
      cleanup();
    }
  });
});
