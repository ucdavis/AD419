import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { fireEvent, screen, waitFor } from '@testing-library/react';
import { server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';

const mockUser = {
  email: 'shannon@example.edu',
  id: 'user-1',
  name: 'Shannon Taylor',
  roles: ['User'],
};

const succeededRun = {
  completedAt: '2026-07-29T10:05:00Z',
  cycleEnd: '2025-09-30',
  cycleStart: '2024-10-01',
  id: 1,
  stages: [
    { completedAt: '2026-07-29T10:01:00Z', errorDetail: null, name: 'ChartSegments: Fund', ordinal: 1, rowCount: 1200, startedAt: '2026-07-29T10:00:00Z', status: 'Succeeded' },
    { completedAt: '2026-07-29T10:05:00Z', errorDetail: null, name: 'AE transactions', ordinal: 9, rowCount: 413_637, startedAt: '2026-07-29T10:01:00Z', status: 'Succeeded' },
  ],
  startedAt: '2026-07-29T10:00:00Z',
  status: 'Succeeded',
  triggeredByName: 'Rob',
};

describe('Data Import stage', () => {
  it('shows the latest run with per-stage row counts', async () => {
    server.use(
      http.get('/api/user/me', () => HttpResponse.json(mockUser)),
      http.get('/api/importruns/current', () => HttpResponse.json(succeededRun))
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-import' });
    try {
      expect(await screen.findByText('AE transactions')).toBeInTheDocument();
      expect(screen.getByText('413,637')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /start import/i })).toBeEnabled();
    } finally {
      cleanup();
    }
  });

  it('starts an import and disables the button while running', async () => {
    let started = false;
    const runningRun = { ...succeededRun, completedAt: null, id: 2, status: 'Running' };
    server.use(
      http.get('/api/user/me', () => HttpResponse.json(mockUser)),
      http.get('/api/importruns/current', () =>
        started ? HttpResponse.json(runningRun) : new HttpResponse(null, { status: 204 })
      ),
      http.post('/api/importruns', () => {
        started = true;
        return HttpResponse.json(runningRun);
      })
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-import' });
    try {
      const start = await screen.findByRole('button', { name: /start import/i });
      fireEvent.click(start);
      await waitFor(() => expect(screen.getByRole('button', { name: /start import/i })).toBeDisabled());
    } finally {
      cleanup();
    }
  });

  it('surfaces stage errors', async () => {
    const failedRun = {
      ...succeededRun,
      id: 3,
      stages: [
        { completedAt: '2026-07-29T10:02:00Z', errorDetail: 'warehouse offline', name: 'AE transactions', ordinal: 9, rowCount: null, startedAt: '2026-07-29T10:01:00Z', status: 'Failed' },
      ],
      status: 'Failed',
    };
    server.use(
      http.get('/api/user/me', () => HttpResponse.json(mockUser)),
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
