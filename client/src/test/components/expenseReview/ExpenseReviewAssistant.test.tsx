import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { screen, waitFor } from '@testing-library/react';
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
    chatUrl: 'https://caes-ai.test/v1/sessions/00000000-0000-4000-8000-000000000001/chat',
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
          'data-classification': 'Complete',
          'data-import': 'Complete',
          'expense-review': 'InProgress',
          'project-identification': 'Complete',
        })
      )
    ),
    http.get('/api/expensereview/filters', () => HttpResponse.json(emptyFilters)),
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
  it('shows the launcher and only creates a session when opened', async () => {
    const user = userEvent.setup();
    const sessionRequests = { count: 0 };
    mockApi(sessionRequests);
    const { cleanup } = renderRoute({ initialPath: '/workflow/expense-review' });

    try {
      const launcher = await screen.findByRole('button', { name: 'Ask CAES AI' });
      expect(sessionRequests.count).toBe(0);

      await user.click(launcher);

      expect(await screen.findByRole('dialog', { name: 'Assistant' })).toBeInTheDocument();
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
    const { cleanup } = renderRoute({ initialPath: '/workflow/expense-review' });

    try {
      await user.click(await screen.findByRole('button', { name: 'Ask CAES AI' }));

      expect(
        await screen.findByText(/unavailable|failed|error/i, {
          selector: '[data-caes-ai-slot="error"], [data-caes-ai-slot="error"] *',
        })
      ).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });
});
