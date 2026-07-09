import { afterEach, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';
import { screen, waitFor } from '@testing-library/react';
import { server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';
import { userEvent } from '@testing-library/user-event';

const mockUser = {
  email: 'shannon@example.edu',
  id: 'user-1',
  name: 'Shannon Taylor',
  roles: ['User'],
};

const projectListResponse = {
  counts: {
    all: 3,
    clean: 1,
    issues: 2,
  },
  cycleEnd: '2026-09-30',
  cycleStart: '2025-10-01',
  fiscalYear: 'FY26',
  rows: [
    {
      accession: '1053852',
      ae: 'K1234',
      awardNumber: '2025-111',
      nifaProject: 'CA-A-111-H',
      orgr: 'ATM',
      pi: 'Larkspur, S.',
      sfn: '201',
      status: 'Clean',
    },
    {
      accession: '1055356',
      ae: 'K2222',
      awardNumber: '2025-222',
      nifaProject: 'CA-B-222-CG',
      orgr: 'ANS',
      pi: 'Okonkwo, Y.',
      sfn: '204',
      status: '204 outside college',
    },
    {
      accession: '1078258',
      ae: null,
      awardNumber: '2025-333',
      nifaProject: 'CA-C-333-CG',
      orgr: 'VEN',
      pi: 'Naidoo, T.',
      sfn: '204',
      status: 'No PGM match',
    },
  ],
  summary: {
    activeNifa: 25,
    allNifa: 42,
    alnCodes: 7,
    issuesToResolve: 2,
    pgmRecords: 18,
    sfnDistribution: [
      { count: 1, sfn: '201' },
      { count: 2, sfn: '204' },
    ],
  },
};

afterEach(() => {
  vi.useRealTimers();
});

describe('AD419 workflow routes', () => {
  it('redirects the authenticated homepage to the first workflow stage', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    vi.setSystemTime(new Date('2026-07-07T12:00:00-07:00'));
    let requestedFy: string | null = null;

    server.use(
      http.get('/api/user/me', () => {
        return HttpResponse.json(mockUser);
      }),
      http.get('/api/imports/recent', () => {
        return HttpResponse.json([]);
      }),
      http.get('/api/projectlist', ({ request }) => {
        requestedFy = new URL(request.url).searchParams.get('fy');
        return HttpResponse.json(projectListResponse);
      })
    );

    const { cleanup, router } = renderRoute({ initialPath: '/' });

    try {
      expect(
        await screen.findByRole('heading', { name: 'Project Identification' })
      ).toBeInTheDocument();

      expect(
        await screen.findByRole('heading', { name: 'Load required data' })
      ).toBeInTheDocument();
      expect(screen.getByLabelText('Dataset')).toBeInTheDocument();
      expect(screen.getByLabelText('Import file')).toBeInTheDocument();
      expect(
        await screen.findByRole('heading', { name: 'Project list · 3' })
      ).toBeInTheDocument();
      expect(screen.getByText('Active NIFA')).toBeInTheDocument();
      expect(screen.getByText('Issues to resolve')).toBeInTheDocument();
      expect(screen.getByRole('tab', { name: /issues\s*2/i })).toHaveAttribute(
        'aria-selected',
        'true'
      );
      expect(
        screen.getByRole('tab', { name: /clean\s*1/i })
      ).toBeInTheDocument();
      expect(screen.getByRole('tab', { name: /all\s*3/i })).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'NIFA Project' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'Accession' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'Award #' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'AE' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'PI' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'ORGR' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'SFN' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'Status' })
      ).toBeInTheDocument();
      expect(screen.getByText('204 outside CAES')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Finalize' })).toBeDisabled();

      await waitFor(() => {
        expect(router.state.location.pathname).toBe(
          '/workflow/project-identification'
        );
      });
      expect(requestedFy).toBe('FY26');
    } finally {
      cleanup();
    }
  });

  it('filters the project list tabs and search text', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    vi.setSystemTime(new Date('2026-07-07T12:00:00-07:00'));
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });

    server.use(
      http.get('/api/user/me', () => {
        return HttpResponse.json(mockUser);
      }),
      http.get('/api/imports/recent', () => {
        return HttpResponse.json([]);
      }),
      http.get('/api/projectlist', () => {
        return HttpResponse.json(projectListResponse);
      })
    );

    const { cleanup } = renderRoute({
      initialPath: '/workflow/project-identification',
    });

    try {
      expect(await screen.findByText('Okonkwo, Y.')).toBeInTheDocument();
      expect(screen.queryByText('Larkspur, S.')).not.toBeInTheDocument();

      await user.click(screen.getByRole('tab', { name: /clean\s*1/i }));
      expect(await screen.findByText('Larkspur, S.')).toBeInTheDocument();
      expect(screen.queryByText('Okonkwo, Y.')).not.toBeInTheDocument();

      await user.click(screen.getByRole('tab', { name: /all\s*3/i }));
      expect(await screen.findByText('Naidoo, T.')).toBeInTheDocument();
      await user.type(
        screen.getByPlaceholderText('Search project, accession, PI...'),
        '1078258'
      );

      expect(screen.getByText('Naidoo, T.')).toBeInTheDocument();
      expect(screen.queryByText('Okonkwo, Y.')).not.toBeInTheDocument();
      expect(screen.queryByText('Larkspur, S.')).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('shows project list errors and retries the query', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    vi.setSystemTime(new Date('2026-07-07T12:00:00-07:00'));
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    let projectListRequests = 0;

    server.use(
      http.get('/api/user/me', () => {
        return HttpResponse.json(mockUser);
      }),
      http.get('/api/imports/recent', () => {
        return HttpResponse.json([]);
      }),
      http.get('/api/projectlist', () => {
        projectListRequests += 1;

        if (projectListRequests === 1) {
          return HttpResponse.json(
            { message: 'Project list unavailable.' },
            { status: 500 }
          );
        }

        return HttpResponse.json(projectListResponse);
      })
    );

    const { cleanup } = renderRoute({
      initialPath: '/workflow/project-identification',
    });

    try {
      expect(
        await screen.findByRole('heading', {
          name: 'Unable to load project list',
        })
      ).toBeInTheDocument();
      expect(
        screen.queryByText('Loading project list...')
      ).not.toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: 'Retry' }));

      expect(
        await screen.findByRole('heading', { name: 'Project list · 3' })
      ).toBeInTheDocument();
      expect(projectListRequests).toBe(2);
    } finally {
      cleanup();
    }
  });

  it('loads any workflow stage directly without locking', async () => {
    server.use(
      http.get('/api/user/me', () => {
        return HttpResponse.json(mockUser);
      }),
      http.get('/api/imports/recent', () => {
        return HttpResponse.json([]);
      })
    );

    const { cleanup, router } = renderRoute({
      initialPath: '/workflow/final-reports',
    });

    try {
      expect(
        await screen.findByRole('heading', { name: 'Final Reports' })
      ).toBeInTheDocument();

      expect(
        await screen.findByRole('heading', { name: 'Coming soon' })
      ).toBeInTheDocument();

      await waitFor(() => {
        expect(router.state.location.pathname).toBe('/workflow/final-reports');
      });
    } finally {
      cleanup();
    }
  });
});
