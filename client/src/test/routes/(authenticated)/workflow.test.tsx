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
      department: 'ATM',
      nifaProject: 'CA-A-111-H',
      pi: 'Larkspur, S.',
      sfn: '201',
      status: 'Clean',
      ucPathName: 'Larkspur, Sasha',
      ucpEmployeeId: '10000001',
    },
    {
      accession: '1055356',
      ae: 'K2222',
      awardNumber: '2025-222',
      department: 'ANS',
      nifaProject: 'CA-B-222-CG',
      pi: 'Okonkwo, Y.',
      sfn: '204',
      status: 'SFN mismatch',
      ucPathName: 'Okonkwo, Yara',
      ucpEmployeeId: '10000002',
    },
    {
      accession: '1078258',
      ae: null,
      awardNumber: '2025-333',
      department: 'VEN',
      nifaProject: 'CA-C-333-CG',
      pi: 'Naidoo, T.',
      sfn: '204',
      status: 'No PGM match',
      ucPathName: 'Naidoo, Talia',
      ucpEmployeeId: '10000003',
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

const setupResponse = {
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
    {
      completed: true,
      hint: 'ANR - all NIFA projects across UC campuses',
      id: 'all-projects',
      kind: 'upload',
      label: 'Upload All Projects List',
      latestImport: {
        attemptedRows: 42,
        dataset: 'all-projects',
        filename: 'all-projects.csv',
        id: 1,
        importedAt: '2026-06-01T12:00:00Z',
        rowsImported: 42,
        status: 'Succeeded',
      },
      number: 2,
      ready: true,
      source: { completedAt: '2026-06-01T12:00:00Z', importLogId: 1, rows: 42 },
      stale: false,
      staleReason: null,
      status: 'done',
    },
    {
      completed: true,
      hint: 'ANR - CAES projects required to report',
      id: 'active-projects',
      kind: 'upload',
      label: 'Upload Active Project List',
      latestImport: {
        attemptedRows: 25,
        dataset: 'active-projects',
        filename: 'active-projects.csv',
        id: 2,
        importedAt: '2026-06-01T12:01:00Z',
        rowsImported: 25,
        status: 'Succeeded',
      },
      number: 3,
      ready: true,
      source: { completedAt: '2026-06-01T12:01:00Z', importLogId: 2, rows: 25 },
      stale: false,
      staleReason: null,
      status: 'done',
    },
    {
      completed: true,
      hint: 'assistancelisting.usaspending.gov - updated weekly',
      id: 'assistance-listing-numbers',
      kind: 'upload',
      label: 'Upload CFDA / ALN Data',
      latestImport: {
        attemptedRows: 7,
        dataset: 'assistance-listing-numbers',
        filename: 'aln.csv',
        id: 3,
        importedAt: '2026-06-01T12:02:00Z',
        rowsImported: 7,
        status: 'Succeeded',
      },
      number: 4,
      ready: true,
      source: { completedAt: '2026-06-01T12:02:00Z', importLogId: 3, rows: 7 },
      stale: false,
      staleReason: null,
      status: 'done',
    },
    {
      completed: true,
      hint: 'AE Redshift - ae_dwh.pgm_master_data',
      id: 'pgm-master-data',
      kind: 'import',
      label: 'Import PGM Master Data',
      number: 5,
      ready: true,
      source: { completedAt: '2026-06-01T12:03:00Z', key: 'pgm', rows: 18 },
      stale: false,
      staleReason: null,
      status: 'done',
    },
    {
      completed: false,
      hint: 'Review flagged projects below',
      id: 'resolve-project-issues',
      kind: 'review',
      label: 'Resolve Project Issues',
      number: 6,
      ready: true,
      source: null,
      stale: false,
      staleReason: null,
      status: 'active',
    },
    {
      completed: false,
      hint: 'Locks project data, triggers full expense pull',
      id: 'finalize-projects',
      kind: 'action',
      label: 'Finalize Projects',
      number: 7,
      ready: false,
      source: null,
      stale: false,
      staleReason: null,
      status: 'locked',
    },
  ],
  completedCount: 5,
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
      http.get('/api/projectidentification/setup', () => {
        return HttpResponse.json(setupResponse);
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
      expect(screen.getByText('5 of 7 complete')).toBeInTheDocument();
      expect(screen.getByText('Confirm Fiscal Period')).toBeInTheDocument();
      expect(screen.getByText('Upload All Projects List')).toBeInTheDocument();
      expect(screen.getByText('Import PGM Master Data')).toBeInTheDocument();
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
        screen.getByRole('columnheader', { name: 'UCP Employee ID' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'UCPath Name' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'Department' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'SFN' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'Status' })
      ).toBeInTheDocument();
      expect(screen.getByText('SFN mismatch')).toBeInTheDocument();

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
      http.get('/api/projectidentification/setup', () => {
        return HttpResponse.json(setupResponse);
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
      const searchInput = screen.getByPlaceholderText(
        'Search project, accession, person...'
      );

      await user.type(searchInput, '1078258');

      expect(screen.getByText('Naidoo, T.')).toBeInTheDocument();
      expect(screen.queryByText('Okonkwo, Y.')).not.toBeInTheDocument();
      expect(screen.queryByText('Larkspur, S.')).not.toBeInTheDocument();

      await user.clear(searchInput);
      await user.type(searchInput, '10000002');

      expect(screen.getByText('Okonkwo, Y.')).toBeInTheDocument();
      expect(screen.getByText('Okonkwo, Yara')).toBeInTheDocument();
      expect(screen.queryByText('Naidoo, T.')).not.toBeInTheDocument();
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
      http.get('/api/projectidentification/setup', () => {
        return HttpResponse.json(setupResponse);
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
