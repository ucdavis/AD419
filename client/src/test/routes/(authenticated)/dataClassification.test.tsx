import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import type { SegmentClassification } from '@/queries/segmentClassifications.ts';
import { createWorkflowSnapshot, server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';

const mockUser = {
  email: 'shannon@example.edu',
  id: 'user-1',
  name: 'Shannon Taylor',
  roles: ['User'],
};

const segments: {
  code: string;
  description: string;
  hierarchy: { code: string; level: string; name: string | null }[];
  includeInReport: boolean | null;
  segmentType: string;
  sfn: string | null;
}[] = [
  { code: '45530', description: 'AES', hierarchy: [], includeInReport: true, segmentType: 'Fund', sfn: '220' },
  { code: '70575', description: 'Berry', hierarchy: [], includeInReport: null, segmentType: 'Fund', sfn: null },
];

function mockApi() {
  let current = [...segments];
  server.use(
    http.get('/api/user/me', () => HttpResponse.json(mockUser)),
    http.get('/api/workflow/snapshot', () =>
      HttpResponse.json(
        createWorkflowSnapshot({
          'data-classification': 'InProgress',
          'data-import': 'Complete',
          'project-identification': 'Complete',
        })
      )
    ),
    http.get('/api/segmentclassifications', () => HttpResponse.json(current)),
    http.patch('/api/segmentclassifications', async ({ request }) => {
      const body = await request.json() as { code: string; includeInReport: boolean; segmentType: string; sfn: string | null };
      current = current.map((s) =>
        s.code === body.code ? { ...s, includeInReport: body.includeInReport } : s
      );
      return new HttpResponse(null, { status: 204 });
    })
  );
}

const completedUpstream = {
  'data-import': 'Complete',
  'project-identification': 'Complete',
} as const;

function mockEditableApi(completed = false) {
  const state: {
    segments: SegmentClassification[];
    snapshot: ReturnType<typeof createWorkflowSnapshot>;
  } = {
    segments: [
      {
        code: '45530', description: 'AES', hierarchy: [],
        includeInReport: true, segmentType: 'Fund', sfn: '220',
      },
      {
        code: 'REG', description: 'Regular earnings', hierarchy: [],
        includeInReport: true, segmentType: 'Ern', sfn: null,
      },
    ],
    snapshot: createWorkflowSnapshot({
      ...completedUpstream,
      'data-classification': completed ? 'Complete' : 'InProgress',
      ...(completed
        ? {
            'auto-associations': 'Complete',
            'expense-review': 'Complete',
            'orgr-review': 'Complete',
          } as const
        : {}),
    }),
  };
  server.use(
    http.get('/api/user/me', () => HttpResponse.json(mockUser)),
    http.get('/api/workflow/snapshot', () => HttpResponse.json(state.snapshot)),
    http.get('/api/segmentclassifications', () =>
      HttpResponse.json(state.segments)
    ),
    http.get('/api/expensereview/filters', () => HttpResponse.json({
      accountingPeriods: [], accounts: [], activities: [], aeProjects: [], entities: [],
      exclusionReasons: [], financialDepts: [], funds: [], programs: [], purposes: [], sfns: [], sources: [],
    })),
  );
  return state;
}

function fundClassification() {
  return within(screen.getByRole('row', { name: /45530/ })).getByRole('combobox');
}

describe('Data Classification stage', () => {
  it.each([
    { earnings: false, fails: false },
    { earnings: false, fails: true },
    { earnings: true, fails: false },
    { earnings: true, fails: true },
  ])('reopens completed review and pauses edits through save and refresh (ERN: $earnings, failure: $fails)', async ({ earnings, fails }) => {
    const state = mockEditableApi(true);
    const save = Promise.withResolvers<void>();
    const saveStarted = Promise.withResolvers<void>();
    const refresh = Promise.withResolvers<void>();
    const refreshStarted = Promise.withResolvers<void>();
    let refreshing = false;
    server.use(
      http.patch('/api/segmentclassifications', async ({ request }) => {
        const body = await request.json() as {
          includeInReport: boolean;
          segmentType: string;
          sfn: string | null;
        };
        saveStarted.resolve();
        await save.promise;
        // Reset succeeds before saving, including the failing-save case.
        state.snapshot = createWorkflowSnapshot({
          ...completedUpstream,
          'data-classification': 'InProgress',
        });
        refreshing = true;
        if (fails) {
          return HttpResponse.text('Could not save the classification.', {
            status: 500,
          });
        }
        state.segments = state.segments.map((segment) =>
          segment.segmentType === body.segmentType
            ? { ...segment, includeInReport: body.includeInReport, sfn: body.sfn }
            : segment
        );
        return new HttpResponse(null, { status: 204 });
      }),
      http.get('/api/workflow/snapshot', async () => {
        if (refreshing) {
          refreshStarted.resolve();
          await refresh.promise;
        }
        return HttpResponse.json(state.snapshot);
      })
    );
    const user = userEvent.setup();
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });
    try {
      await user.click(
        await screen.findByRole('tab', { name: earnings ? /ERN/ : /Fund/ })
      );
      expect(screen.getByText(/Changing a classification reopens this step/)).toBeInTheDocument();
      expect(screen.queryByRole('button', { name: /Continue to Expense Review/ })).not.toBeInTheDocument();
      expect(screen.getByRole('link', { name: /Auto-Associations/ })).toBeInTheDocument();
      if (earnings) {
        await user.click(screen.getByRole('button', { name: 'Exclude' }));
      } else {
        await user.selectOptions(fundClassification(), '201');
      }
      await saveStarted.promise;
      await user.click(screen.getByRole('tab', { name: /Fund/ }));
      expect(fundClassification()).toBeDisabled();
      await user.click(screen.getByRole('tab', { name: /ERN/ }));
      expect(screen.getByRole('button', { name: 'Include' })).toBeDisabled();
      expect(screen.getByRole('button', { name: 'Exclude' })).toBeDisabled();

      save.resolve();
      await refreshStarted.promise;
      expect(screen.getByRole('button', { name: 'Include' })).toBeDisabled();
      await user.click(screen.getByRole('tab', { name: /Fund/ }));
      await waitFor(() =>
        expect(fundClassification()).toHaveValue(!earnings && !fails ? '201' : '220')
      );
      expect(fundClassification()).toBeDisabled();

      refresh.resolve();
      await waitFor(() => expect(fundClassification()).toBeEnabled());
      expect(screen.getByRole('button', { name: /Continue to Expense Review/ })).toBeEnabled();
      expect(screen.getByRole('button', { name: /Expense Review.*Locked/ })).toBeDisabled();
      expect(screen.getByRole('button', { name: /OrgR Review.*Locked/ })).toBeDisabled();
      expect(screen.getByRole('button', { name: /Auto-Associations.*Locked/ })).toBeDisabled();
      expect(screen.getByRole('link', { name: /Data Import.*Complete/ })).toBeInTheDocument();
      if (fails) {
        expect(await screen.findByRole('alert')).toHaveTextContent('Could not save the classification.');
      }
    } finally {
      save.resolve();
      refresh.resolve();
      cleanup();
    }
  });

  it.each([false, true])('pauses classification edits during completion (failure: %s)', async (fails) => {
    const state = mockEditableApi();
    const completion = Promise.withResolvers<void>();
    const completionStarted = Promise.withResolvers<void>();
    server.use(http.put('/api/workflow/stages/data-classification', async () => {
      completionStarted.resolve();
      await completion.promise;
      if (fails) {
        return HttpResponse.text('Could not complete classification.', { status: 500 });
      }
      state.snapshot = createWorkflowSnapshot({
        ...completedUpstream,
        'data-classification': 'Complete',
      });
      return HttpResponse.json(state.snapshot);
    }));
    const user = userEvent.setup();
    const { cleanup, router } = renderRoute({ initialPath: '/workflow/data-classification' });
    try {
      await user.click(await screen.findByRole('tab', { name: /Fund/ }));
      await user.click(screen.getByRole('button', { name: /Continue to Expense Review/ }));
      await completionStarted.promise;
      expect(fundClassification()).toBeDisabled();
      expect(screen.getByRole('button', { name: /Continuing/ })).toBeDisabled();
      await user.click(screen.getByRole('tab', { name: /ERN/ }));
      expect(screen.getByRole('button', { name: 'Include' })).toBeDisabled();
      expect(screen.getByRole('button', { name: 'Exclude' })).toBeDisabled();
      completion.resolve();
      if (fails) {
        expect(await screen.findByRole('alert')).toHaveTextContent('Could not complete classification.');
        await waitFor(() => expect(screen.getByRole('button', { name: 'Include' })).toBeEnabled());
        expect(screen.getByRole('button', { name: 'Exclude' })).toBeEnabled();
        expect(screen.getByRole('button', { name: /Continue to Expense Review/ })).toBeEnabled();
        expect(router.state.location.pathname).toBe('/workflow/data-classification');
      } else {
        await waitFor(() => expect(router.state.location.pathname).toBe('/workflow/expense-review'));
      }
    } finally {
      completion.resolve();
      cleanup();
    }
  });

  it('keeps Continue disabled when classifications cannot be loaded', async () => {
    mockEditableApi();
    server.use(http.get('/api/segmentclassifications', () =>
      HttpResponse.text('Could not load classifications.', { status: 500 })
    ));
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });
    try {
      expect(await screen.findByRole('alert')).toHaveTextContent('Could not load classifications.');
      expect(screen.getByRole('button', { name: /Continue to Expense Review/ })).toBeDisabled();
    } finally {
      cleanup();
    }
  });

  it('renders the classifier with tabs instead of the placeholder', async () => {
    mockApi();
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });

    try {
      expect(await screen.findByRole('tab', { name: /Fund/ })).toBeInTheDocument();
      expect(screen.getByRole('tab', { name: /Financial Dept/ })).toBeInTheDocument();
      expect(screen.queryByRole('heading', { name: 'Coming soon' })).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('blocks Continue until every segment is classified, then opens the gate', async () => {
    mockApi();
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });

    try {
      const fundTab = await screen.findByRole('tab', { name: /Fund/ });
      fireEvent.click(fundTab);

      await screen.findByText('70575');

      expect(
        screen.getByRole('button', { name: /Continue to Expense Review/ })
      ).toBeDisabled();

      const dropdowns = screen.getAllByRole<HTMLSelectElement>('combobox');
      const unsetDropdown = dropdowns.find((dropdown) => dropdown.value === '');
      fireEvent.change(unsetDropdown!, { target: { value: '201' } });

      await waitFor(() => {
        expect(
          screen.getByRole('button', { name: /Continue to Expense Review/ })
        ).toBeEnabled();
      });
    } finally {
      cleanup();
    }
  });

  it('continues to expense review after updating the workflow stage', async () => {
    let updateRequests = 0;
    server.use(
      http.get('/api/user/me', () => HttpResponse.json(mockUser)),
      http.get('/api/workflow/snapshot', () =>
        HttpResponse.json(
          createWorkflowSnapshot({
            'data-classification': updateRequests > 0 ? 'Complete' : 'InProgress',
            'data-import': 'Complete',
            'expense-review': updateRequests > 0 ? 'InProgress' : 'NotStarted',
            'project-identification': 'Complete',
          })
        )
      ),
      http.get('/api/segmentclassifications', () =>
        HttpResponse.json(
          segments.map((segment) => ({
            ...segment,
            includeInReport: true,
            sfn: segment.segmentType === 'Fund' ? '201' : null,
          }))
        )
      ),
      http.get('/api/expensereview/filters', () =>
        HttpResponse.json({
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
        })
      ),
      http.get('/api/expensereview/transactions', () =>
        HttpResponse.json({
          counts: { all: 0, excluded: 0, included: 0 },
          cycleEnd: '2026-09-30',
          cycleStart: '2025-10-01',
          fiscalYear: 'FY26',
          page: 1,
          pageCount: 0,
          pageSize: 25,
          rows: [],
          totalCount: 0,
        })
      ),
      http.put('/api/workflow/stages/:stageId', async ({ params, request }) => {
        expect(params.stageId).toBe('data-classification');
        expect(await request.json()).toEqual({ status: 'Complete' });
        updateRequests += 1;
        return HttpResponse.json(
          createWorkflowSnapshot({
            'data-classification': 'Complete',
            'data-import': 'Complete',
            'expense-review': 'InProgress',
            'project-identification': 'Complete',
          })
        );
      })
    );
    const { cleanup, router } = renderRoute({
      initialPath: '/workflow/data-classification',
    });

    try {
      fireEvent.click(
        await screen.findByRole('button', {
          name: /continue to expense review/i,
        })
      );

      await waitFor(() => {
        expect(updateRequests).toBe(1);
        expect(router.state.location.pathname).toBe('/workflow/expense-review');
      });
    } finally {
      cleanup();
    }
  });

  it('shows the FTE disclaimer only on the ERN tab', async () => {
    mockApi();
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });

    try {
      await screen.findByRole('tab', { name: /Fund/ });
      expect(
        screen.queryByText(/affects fte calculations only/i)
      ).not.toBeInTheDocument();

      fireEvent.click(screen.getByRole('tab', { name: /ERN/ }));

      expect(
        await screen.findByText(/affects fte calculations only/i)
      ).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });
});
