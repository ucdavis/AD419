import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { fireEvent, screen, waitFor } from '@testing-library/react';
import { createWorkflowSnapshot, server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';

const mockUser = {
  email: 'shannon@example.edu',
  id: 'user-1',
  name: 'Shannon Taylor',
  roles: ['User'],
};

const setupResponse = {
  checklistItems: [],
  completedCount: 7,
  cycleEnd: '2026-09-30',
  cycleStart: '2025-10-01',
  fiscalPeriodOptions: [
    {
      cycleEnd: '2026-09-30',
      cycleStart: '2025-10-01',
      fiscalYear: 'FY26',
      label: 'FY:26 - Oct 2025 - Sep 2026',
    },
  ],
  fiscalYear: 'FY26',
  totalCount: 7,
  workflowRunId: 1,
};

const succeededRun = {
  completedAt: '2026-07-29T10:05:00Z',
  cycleEnd: '2026-09-30',
  cycleStart: '2025-10-01',
  id: 1,
  stages: [
    { completedAt: '2026-07-29T10:01:00Z', detail: null, errorDetail: null, name: 'ChartSegments: Fund', ordinal: 1, rowCount: 1200, startedAt: '2026-07-29T10:00:00Z', status: 'Succeeded' },
    { completedAt: '2026-07-29T10:02:00Z', detail: '479 AE projects, 364 NIFA projects', errorDetail: null, name: 'Build projects', ordinal: 8, rowCount: 479, startedAt: '2026-07-29T10:01:00Z', status: 'Succeeded' },
    { completedAt: '2026-07-29T10:05:00Z', detail: null, errorDetail: null, name: 'AE transactions', ordinal: 9, rowCount: 413_637, startedAt: '2026-07-29T10:02:00Z', status: 'Succeeded' },
  ],
  startedAt: '2026-07-29T10:00:00Z',
  status: 'Succeeded',
  triggeredByName: 'Rob',
};

function useSetupHandler() {
  server.use(
    http.get('/api/user/me', () => HttpResponse.json(mockUser)),
    http.get('/api/workflow/snapshot', () =>
      HttpResponse.json(
        createWorkflowSnapshot({
          'data-import': 'InProgress',
          'project-identification': 'Complete',
        })
      )
    ),
    http.get('/api/projectidentification/setup', () =>
      HttpResponse.json(setupResponse)
    )
  );
}

describe('Data Import stage', () => {
  it('shows the fiscal period from project identification with the buffered window', async () => {
    useSetupHandler();
    server.use(
      http.get('/api/importruns/current', () => new HttpResponse(null, { status: 204 }))
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-import' });
    try {
      expect(await screen.findByDisplayValue('FY:26')).toBeInTheDocument();
      expect(
        screen.getByDisplayValue('FY:26 - Oct 2025 - Sep 2026')
      ).toBeInTheDocument();
      expect(screen.getByText(/Jul 1, 2025/)).toBeInTheDocument();
      expect(screen.getByText(/Dec 30, 2026/)).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('shows the latest run with per-stage row counts', async () => {
    useSetupHandler();
    server.use(
      http.get('/api/importruns/current', () => HttpResponse.json(succeededRun))
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-import' });
    try {
      expect(await screen.findByText('AE transactions')).toBeInTheDocument();
      expect(screen.getByText('413,637')).toBeInTheDocument();
      expect(
        screen.getByText('479 AE projects, 364 NIFA projects')
      ).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /start import/i })).toBeEnabled();
    } finally {
      cleanup();
    }
  });

  it('continues to classification after updating the workflow stage', async () => {
    let updateRequests = 0;
    useSetupHandler();
    server.use(
      http.get('/api/importruns/current', () => HttpResponse.json(succeededRun)),
      http.put('/api/workflow/stages/:stageId', async ({ params, request }) => {
        expect(params.stageId).toBe('data-import');
        expect(await request.json()).toEqual({ status: 'Complete' });
        updateRequests += 1;
        return HttpResponse.json(
          createWorkflowSnapshot({
            'data-classification': 'InProgress',
            'data-import': 'Complete',
            'project-identification': 'Complete',
          })
        );
      }),
      http.get('/api/segmentclassifications', () => HttpResponse.json([]))
    );
    const { cleanup, router } = renderRoute({ initialPath: '/workflow/data-import' });
    try {
      fireEvent.click(
        await screen.findByRole('button', {
          name: /continue to data classification/i,
        })
      );

      await waitFor(() => {
        expect(updateRequests).toBe(1);
        expect(router.state.location.pathname).toBe(
          '/workflow/data-classification'
        );
      });
    } finally {
      cleanup();
    }
  });

  it('starts an import without posting dates and disables the button while running', async () => {
    let started = false;
    let postedBody: string | null = null;
    const runningRun = { ...succeededRun, completedAt: null, id: 2, status: 'Running' };
    useSetupHandler();
    server.use(
      http.get('/api/importruns/current', () =>
        started ? HttpResponse.json(runningRun) : new HttpResponse(null, { status: 204 })
      ),
      http.post('/api/importruns', async ({ request }) => {
        started = true;
        postedBody = await request.text();
        return HttpResponse.json(runningRun);
      })
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-import' });
    try {
      const start = await screen.findByRole('button', { name: /start import/i });
      fireEvent.click(start);
      await waitFor(() => expect(screen.getByRole('button', { name: /start import/i })).toBeDisabled());
      // the server sources the cycle from the confirmed fiscal period
      expect(postedBody).toBe('');
    } finally {
      cleanup();
    }
  });

  it('shows an error with retry when the import run cannot be loaded', async () => {
    let requests = 0;
    useSetupHandler();
    server.use(
      http.get('/api/importruns/current', () => {
        requests += 1;
        return requests > 1
          ? HttpResponse.json(succeededRun)
          : new HttpResponse(null, { status: 500 });
      })
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-import' });
    try {
      expect(
        await screen.findByRole('heading', { name: 'Unable to load import status' })
      ).toBeInTheDocument();
      expect(
        screen.queryByText('No import has run yet for this cycle.')
      ).not.toBeInTheDocument();
      expect(
        screen.queryByRole('button', { name: /start import/i })
      ).not.toBeInTheDocument();

      fireEvent.click(screen.getByRole('button', { name: 'Retry' }));

      expect(await screen.findByText('AE transactions')).toBeInTheDocument();
      expect(requests).toBe(2);
    } finally {
      cleanup();
    }
  });

  it('shows the server explanation when starting the import fails', async () => {
    useSetupHandler();
    server.use(
      http.get('/api/importruns/current', () => new HttpResponse(null, { status: 204 })),
      http.post(
        '/api/importruns',
        () =>
          new HttpResponse('An import run is already in progress.', {
            status: 409,
          })
      )
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-import' });
    try {
      fireEvent.click(await screen.findByRole('button', { name: /start import/i }));
      expect(
        await screen.findByText('An import run is already in progress.')
      ).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('surfaces stage errors', async () => {
    const failedRun = {
      ...succeededRun,
      id: 3,
      stages: [
        { completedAt: '2026-07-29T10:02:00Z', detail: null, errorDetail: 'warehouse offline', name: 'AE transactions', ordinal: 9, rowCount: null, startedAt: '2026-07-29T10:01:00Z', status: 'Failed' },
      ],
      status: 'Failed',
    };
    useSetupHandler();
    server.use(
      http.get('/api/importruns/current', () => HttpResponse.json(failedRun))
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-import' });
    try {
      expect(await screen.findByText(/warehouse offline/)).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });
});
