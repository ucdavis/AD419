import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';
import { act, render, screen, waitFor } from '@testing-library/react';
import { AssistantToast } from '@/components/expenseReview/ExpenseReviewAssistant.tsx';
import { createWorkflowSnapshot, server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';
import { userEvent } from '@testing-library/user-event';

const mockUser = {
  email: 'shannon@example.edu',
  id: 'user-1',
  name: 'Shannon Taylor',
  roles: ['User'],
};

const emptyFilters = {
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
};

const emptyTransactions = {
  counts: { all: 0, excluded: 0, included: 0 },
  cycleEnd: '2026-09-30',
  cycleStart: '2025-10-01',
  fiscalYear: 'FY26',
  page: 1,
  pageCount: 0,
  pageSize: 25,
  rows: [],
  totalAmount: 0,
  totalCount: 0,
};

function sessionResponse() {
  return {
    accessToken: 'browser-session-token-that-is-long-enough-for-zod',
    chatUrl:
      'https://caes-ai.test/v1/sessions/00000000-0000-4000-8000-000000000001/chat',
    expiresAt: new Date(Date.now() + 60_000).toISOString(),
    modelPolicy: {
      allowedReasoningEfforts: ['none'],
      defaultReasoningEffort: 'none',
      maximumReasoningEffort: 'none',
      model: 'gpt-5.6-luna',
    },
    protocolVersion: 1,
    sessionId: '00000000-0000-4000-8000-000000000001',
    toolManifestHash: 'a'.repeat(64),
    tools: [],
  };
}

function mockApi(sessionRequests: { count: number }) {
  server.use(
    http.get('/api/user/me', () => HttpResponse.json(mockUser)),
    http.get('/api/workflow/snapshot', () =>
      HttpResponse.json(
        createWorkflowSnapshot({
          'auto-associations': 'Complete',
          'data-classification': 'Complete',
          'data-import': 'Complete',
          'expense-review': 'Complete',
          'manual-associations': 'InProgress',
          'orgr-review': 'Complete',
          'project-identification': 'Complete',
        })
      )
    ),
    http.get('/api/expensereview/filters', () =>
      HttpResponse.json(emptyFilters)
    ),
    http.get('/api/expensereview/transactions', () =>
      HttpResponse.json(emptyTransactions)
    ),
    http.post('/api/assistant/session', () => {
      sessionRequests.count += 1;
      return HttpResponse.json(sessionResponse());
    })
  );
}

describe('Expense Review assistant', () => {
  beforeEach(() => {
    vi.stubGlobal('matchMedia', () => ({
      addEventListener: vi.fn(),
      matches: true,
      removeEventListener: vi.fn(),
    }));
    server.use(
      http.get('/api/workflow/documentation', () => HttpResponse.json({}))
    );
  });
  afterEach(() => vi.unstubAllGlobals());

  it('preserves draft across tabs and closing, then disposes it on stage navigation', async () => {
    const user = userEvent.setup();
    const sessionRequests = { count: 0 };
    mockApi(sessionRequests);
    const { cleanup, router } = renderRoute({
      initialPath: '/workflow/expense-review',
    });
    try {
      await user.click(
        await screen.findByRole('button', { name: 'Documentation' })
      );
      await screen.findByText(
        'Documentation has not been configured for this stage.'
      );
      expect(sessionRequests.count).toBe(0);
      await user.click(screen.getByRole('tab', { name: 'Ask CAES AI' }));
      const composer = await screen.findByPlaceholderText(
        'Ask about expense review'
      );
      await waitFor(() => expect(sessionRequests.count).toBe(1));
      await user.type(composer, 'Keep my draft');
      await user.click(screen.getByRole('tab', { name: 'Documentation' }));
      expect(composer.closest('[role="tabpanel"]')).toHaveAttribute('inert');
      await user.click(
        screen.getByRole('button', { name: 'Close help drawer' })
      );
      await user.click(screen.getByRole('button', { name: 'Ask CAES AI' }));
      expect(
        screen.getByPlaceholderText('Ask about expense review')
      ).toHaveValue('Keep my draft');
      expect(sessionRequests.count).toBe(1);
      await act(() =>
        router.navigate({
          params: { stageId: 'manual-associations' },
          to: '/workflow/$stageId',
        })
      );
      expect(
        screen.queryByPlaceholderText('Ask about expense review')
      ).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('does not move focus when a session finishes while Documentation is selected', async () => {
    const user = userEvent.setup();
    mockApi({ count: 0 });
    const ready = Promise.withResolvers<void>();
    const started = Promise.withResolvers<void>();
    server.use(
      http.post('/api/assistant/session', async () => {
        started.resolve();
        await ready.promise;
        return HttpResponse.json(sessionResponse());
      })
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review',
    });
    try {
      await user.click(
        await screen.findByRole('button', { name: 'Ask CAES AI' })
      );
      await started.promise;
      await user.click(screen.getByRole('tab', { name: 'Documentation' }));
      const docs = screen.getByRole('tab', { name: 'Documentation' });
      await act(async () => {
        ready.resolve();
      });
      await waitFor(() =>
        expect(
          screen.getByPlaceholderText('Ask about expense review')
        ).not.toBeDisabled()
      );
      expect(docs).toHaveFocus();
      expect(document.querySelector('#assistant-panel')).toHaveAttribute(
        'inert'
      );
    } finally {
      ready.resolve();
      cleanup();
    }
  });

  it('preserves sent messages across tab changes and closing', async () => {
    const user = userEvent.setup();
    mockApi({ count: 0 });
    server.use(
      http.post(
        sessionResponse().chatUrl,
        () =>
          new HttpResponse(
            [
              {
                runId: 'test-run',
                threadId: 'test-thread',
                type: 'RUN_STARTED',
              },
              {
                messageId: 'reply',
                role: 'assistant',
                type: 'TEXT_MESSAGE_START',
              },
              {
                delta: 'Review complete.',
                messageId: 'reply',
                type: 'TEXT_MESSAGE_CONTENT',
              },
              { messageId: 'reply', type: 'TEXT_MESSAGE_END' },
              {
                runId: 'test-run',
                threadId: 'test-thread',
                type: 'RUN_FINISHED',
              },
            ]
              .map(
                (event) =>
                  `data: ${JSON.stringify({ ...event, metadata: { caesAi: { protocolVersion: 1 } } })}\n\n`
              )
              .join(''),
            {
              headers: {
                'Content-Type': 'text/event-stream',
                'X-CAES-AI-Protocol-Version': '1',
              },
            }
          )
      )
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review',
    });
    try {
      await user.click(
        await screen.findByRole('button', { name: 'Ask CAES AI' })
      );
      const composer = await screen.findByPlaceholderText(
        'Ask about expense review'
      );
      await waitFor(() => expect(composer).not.toBeDisabled());
      await user.type(composer, 'Check my expenses');
      await user.click(
        screen.getByRole('button', { name: /^Send$/ })
      );
      await screen.findByText('Review complete.');
      await user.click(screen.getByRole('tab', { name: 'Documentation' }));
      await user.click(
        screen.getByRole('button', { name: 'Close help drawer' })
      );
      await user.click(screen.getByRole('button', { name: 'Ask CAES AI' }));
      expect(screen.getByText('Check my expenses')).toBeVisible();
      expect(screen.getByText('Review complete.')).toBeVisible();
    } finally {
      cleanup();
    }
  });

  it('shows the launcher and only creates a session when opened', async () => {
    const user = userEvent.setup();
    const sessionRequests = { count: 0 };
    mockApi(sessionRequests);
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review',
    });

    try {
      const launcher = await screen.findByRole('button', {
        name: 'Ask CAES AI',
      });
      expect(sessionRequests.count).toBe(0);

      await user.click(launcher);

      expect(
        await screen.findByRole('complementary', { name: 'Stage help' })
      ).toBeInTheDocument();
      await waitFor(() => {
        expect(sessionRequests.count).toBe(1);
      });
    } finally {
      cleanup();
    }
  });

  it('shows an error state when the session endpoint fails', async () => {
    const user = userEvent.setup();
    mockApi({ count: 0 });
    server.use(
      http.post('/api/assistant/session', () =>
        HttpResponse.json(
          { title: 'The assistant service is unavailable.' },
          { status: 503 }
        )
      )
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review',
    });

    try {
      await user.click(
        await screen.findByRole('button', { name: 'Ask CAES AI' })
      );

      expect(
        await screen.findByText(/unavailable|failed|error/i, {
          selector:
            '[data-caes-ai-slot="error"], [data-caes-ai-slot="error"] *',
        })
      ).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });
});

describe('AssistantToast', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('resets the dismiss timer when a new toast replaces the old one', () => {
    const onDismiss = vi.fn();
    const { rerender } = render(
      <AssistantToast
        onDismiss={onDismiss}
        toast={{ level: 'info', message: 'first' }}
      />
    );
    expect(screen.getByText('first')).toBeInTheDocument();

    act(() => {
      vi.advanceTimersByTime(3000);
    });
    rerender(
      <AssistantToast
        onDismiss={onDismiss}
        toast={{ level: 'success', message: 'second' }}
      />
    );
    expect(screen.getByText('second')).toBeInTheDocument();

    act(() => {
      vi.advanceTimersByTime(3000);
    });
    expect(onDismiss).not.toHaveBeenCalled();

    act(() => {
      vi.advanceTimersByTime(1000);
    });
    expect(onDismiss).toHaveBeenCalledTimes(1);
  });

  it('clears its timer on unmount so it never fires late', () => {
    const onDismiss = vi.fn();
    const { unmount } = render(
      <AssistantToast
        onDismiss={onDismiss}
        toast={{ level: 'error', message: 'unmount me' }}
      />
    );

    unmount();
    act(() => {
      vi.advanceTimersByTime(4000);
    });

    expect(onDismiss).not.toHaveBeenCalled();
  });
});
