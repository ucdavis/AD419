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
    excluded: 1,
    issues: 2,
  },
  cycleEnd: '2026-09-30',
  cycleStart: '2025-10-01',
  excludedRows: [
    {
      accession: '1088888',
      ae: null,
      awardNumber: '2025-444',
      department: 'PLS',
      is204: true,
      nifaProject: 'CA-D-444-CG',
      notes: 'Excluded from associations',
      pdEmailAddress: 'singh@example.edu',
      pi: 'Singh, R.',
      sfn: '204',
      status: 'Excluded',
      ucPathName: 'Singh, Riya',
      ucpEmployeeId: '10000004',
    },
  ],
  fiscalYear: 'FY26',
  rows: [
    {
      accession: '1053852',
      ae: 'K1234',
      awardNumber: '2025-111',
      department: 'ATM',
      is204: false,
      nifaProject: 'CA-A-111-H',
      notes: null,
      pdEmailAddress: 'larkspur@example.edu',
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
      is204: true,
      nifaProject: 'CA-B-222-CG',
      notes: 'Needs SFN review',
      pdEmailAddress: 'okonkwo@example.edu',
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
      is204: true,
      nifaProject: 'CA-C-333-CG',
      notes: null,
      pdEmailAddress: 'naidoo@example.edu',
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
    excludedNifa: 1,
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
        await screen.findByRole('heading', {
          name: 'Project list · 3 active (1 excluded from associations)',
        })
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
        screen.getByRole('tab', { name: /excluded\s*1/i })
      ).toBeInTheDocument();
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
        screen.getByRole('columnheader', { name: '204' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'PI' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'PD Email' })
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
      expect(
        screen.getByRole('columnheader', { name: 'Notes' })
      ).toBeInTheDocument();
      expect(
        screen.getByRole('columnheader', { name: 'Actions' })
      ).toBeInTheDocument();
      expect(screen.getByText('SFN mismatch')).toBeInTheDocument();
      expect(screen.queryByText('Singh, R.')).not.toBeInTheDocument();

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
      expect(screen.queryByText('Singh, R.')).not.toBeInTheDocument();

      await user.click(screen.getByRole('tab', { name: /clean\s*1/i }));
      expect(await screen.findByText('Larkspur, S.')).toBeInTheDocument();
      expect(screen.queryByText('Okonkwo, Y.')).not.toBeInTheDocument();
      expect(screen.queryByText('Singh, R.')).not.toBeInTheDocument();

      await user.click(screen.getByRole('tab', { name: /all\s*3/i }));
      expect(await screen.findByText('Naidoo, T.')).toBeInTheDocument();
      expect(screen.queryByText('Singh, R.')).not.toBeInTheDocument();
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

      await user.clear(searchInput);
      await user.click(screen.getByRole('tab', { name: /excluded\s*1/i }));

      expect(await screen.findByText('Singh, R.')).toBeInTheDocument();
      expect(screen.getByText('Excluded from associations')).toBeInTheDocument();
      expect(screen.queryByText('Okonkwo, Y.')).not.toBeInTheDocument();
      expect(
        screen.queryByRole('button', { name: 'Exclude' })
      ).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('resolves an SFN mismatch and refetches the project list', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    vi.setSystemTime(new Date('2026-07-07T12:00:00-07:00'));
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    const fy25SetupResponse = {
      ...setupResponse,
      cycleEnd: '2025-09-30',
      cycleStart: '2024-10-01',
      fiscalPeriodOptions: [
        {
          cycleEnd: '2025-09-30',
          cycleStart: '2024-10-01',
          fiscalYear: 'FY25',
          label: 'FY:25 - Oct 2024 - Sep 2025',
        },
      ],
      fiscalYear: 'FY25',
    };
    const fy25ProjectListResponse = {
      ...projectListResponse,
      cycleEnd: '2025-09-30',
      cycleStart: '2024-10-01',
      fiscalYear: 'FY25',
    };
    let currentProjectList = fy25ProjectListResponse;
    let postedSfn: string | null = null;
    let projectListRequests = 0;
    let sfnCandidateFy: string | null = null;
    let postedFy: string | null = null;

    server.use(
      http.get('/api/user/me', () => {
        return HttpResponse.json(mockUser);
      }),
      http.get('/api/imports/recent', () => {
        return HttpResponse.json([]);
      }),
      http.get('/api/projectidentification/setup', () => {
        return HttpResponse.json(fy25SetupResponse);
      }),
      http.get('/api/projectlist', ({ request }) => {
        expect(new URL(request.url).searchParams.get('fy')).toBe('FY25');
        projectListRequests += 1;
        return HttpResponse.json(currentProjectList);
      }),
      http.get(
        '/api/projectlist/:accession/sfn-candidates',
        ({ params, request }) => {
          expect(params.accession).toBe('1055356');
          sfnCandidateFy = new URL(request.url).searchParams.get('fy');
          return HttpResponse.json([
            {
              description: 'Hatch Funds',
              isRecommended: false,
              sfn: '201',
              source: null,
            },
            {
              description: 'OtherFunds(AnimalHealthSec1433,Evans-Allen)',
              isRecommended: true,
              sfn: '205',
              source: 'PGM master data',
            },
          ]);
        }
      ),
      http.post(
        '/api/projectlist/:accession/set-sfn',
        async ({ params, request }) => {
          expect(params.accession).toBe('1055356');
          postedFy = new URL(request.url).searchParams.get('fy');
          const body = (await request.json()) as { sfn: string };
          postedSfn = body.sfn;
          currentProjectList = {
            ...fy25ProjectListResponse,
            counts: { all: 3, clean: 2, excluded: 1, issues: 1 },
            rows: fy25ProjectListResponse.rows.map((row) =>
              row.accession === '1055356'
                ? { ...row, sfn: body.sfn, status: 'Clean' }
                : row
            ),
            summary: {
              ...fy25ProjectListResponse.summary,
              issuesToResolve: 1,
            },
          };
          return new HttpResponse(null, { status: 204 });
        }
      )
    );

    const { cleanup } = renderRoute({
      initialPath: '/workflow/project-identification',
    });

    try {
      expect(await screen.findByText('SFN mismatch')).toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: 'Select SFN' }));
      await user.click(
        await screen.findByRole('button', {
          name: '205 - OtherFunds(AnimalHealthSec1433,Evans-Allen) · PGM master data',
        })
      );

      await waitFor(() => {
        expect(postedSfn).toBe('205');
        expect(sfnCandidateFy).toBe('FY25');
        expect(postedFy).toBe('FY25');
        expect(projectListRequests).toBeGreaterThanOrEqual(2);
        expect(screen.queryByText('SFN mismatch')).not.toBeInTheDocument();
      });
    } finally {
      cleanup();
    }
  });

  it('allows project resolution dropdowns to be cancelled', async () => {
    const user = userEvent.setup();
    const resolutionProjectListResponse = {
      ...projectListResponse,
      counts: { all: 4, clean: 1, excluded: 1, issues: 3 },
      rows: [
        ...projectListResponse.rows,
        {
          accession: '1099999',
          ae: null,
          awardNumber: '2025-555',
          department: 'PLS',
          is204: false,
          nifaProject: 'CA-D-555-H',
          notes: null,
          pdEmailAddress: 'chen@example.edu',
          pi: 'Chen, Mira',
          sfn: '201',
          status: 'Not in All Projects',
          ucPathName: 'Chen, Mira',
          ucpEmployeeId: '10000005',
        },
      ],
      summary: {
        ...projectListResponse.summary,
        issuesToResolve: 3,
      },
    };

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
        return HttpResponse.json(resolutionProjectListResponse);
      }),
      http.get('/api/projectlist/:accession/sfn-candidates', () => {
        return HttpResponse.json([
          {
            description: 'Hatch Funds',
            isRecommended: true,
            sfn: '201',
            source: 'PGM master data',
          },
        ]);
      }),
      http.get('/api/projectlist/:accession/pgm-award-candidates', () => {
        return HttpResponse.json([
          {
            awardKey: 'award-1',
            awardName: 'Viticulture Research',
            pgmSfnBucket: '204',
            principalInvestigatorNames: 'Naidoo, Talia',
            projectNumbers: 'CA-C-333-CG',
            sponsorAwardNumber: '2025-333',
          },
        ]);
      }),
      http.get('/api/projectlist/:accession/all-project-candidates', () => {
        return HttpResponse.json([
          {
            accessionNumber: '1099999',
            allProjectId: 1,
            awardNumber: '2025-555',
            department: 'PLS',
            projectDirector: 'Chen, Mira',
            projectEndDate: null,
            projectNumber: 'CA-D-555-H',
            projectStartDate: null,
            title: 'Plant Sciences Research',
          },
        ]);
      })
    );

    const { cleanup } = renderRoute({
      initialPath: '/workflow/project-identification',
    });

    try {
      expect(await screen.findByText('SFN mismatch')).toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: 'Select SFN' }));
      expect(
        await screen.findByRole('button', { name: /201 - Hatch Funds/ })
      ).toBeInTheDocument();
      await user.click(screen.getByRole('button', { name: 'Cancel' }));

      await waitFor(() => {
        expect(
          screen.queryByRole('button', { name: /201 - Hatch Funds/ })
        ).not.toBeInTheDocument();
      });

      await user.click(
        screen.getByRole('button', { name: 'Select PGM award' })
      );
      expect(await screen.findByLabelText('Search candidates')).toBeInTheDocument();
      await user.keyboard('{Escape}');

      await waitFor(() => {
        expect(
          screen.queryByLabelText('Search candidates')
        ).not.toBeInTheDocument();
      });

      await user.click(
        screen.getByRole('button', { name: 'Select All Projects' })
      );
      expect(await screen.findByLabelText('Search candidates')).toBeInTheDocument();
      await user.click(screen.getByText('Active NIFA'));

      await waitFor(() => {
        expect(
          screen.queryByLabelText('Search candidates')
        ).not.toBeInTheDocument();
      });
    } finally {
      cleanup();
    }
  });

  it('confirms exclude actions and shows server resolution errors', async () => {
    const user = userEvent.setup();
    let excludeRequests = 0;

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
      }),
      http.post('/api/projectlist/:accession/exclude', ({ params }) => {
        expect(params.accession).toBe('1078258');
        excludeRequests += 1;
        return HttpResponse.text('Project has status Clean.', {
          status: 409,
        });
      })
    );

    const { cleanup } = renderRoute({
      initialPath: '/workflow/project-identification',
    });

    try {
      expect(await screen.findByText('No PGM match')).toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: 'Exclude' }));

      expect(excludeRequests).toBe(0);
      expect(
        await screen.findByRole('dialog', { name: 'Exclude project?' })
      ).toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: 'Exclude project' }));

      expect(
        await screen.findByText('Project has status Clean.')
      ).toBeInTheDocument();
      expect(excludeRequests).toBe(1);
    } finally {
      cleanup();
    }
  });

  it('enables finalize when project issues are resolved', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    vi.setSystemTime(new Date('2026-07-07T12:00:00-07:00'));
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    let finalizeRequests = 0;
    const cleanProjectList = {
      ...projectListResponse,
      counts: { all: 3, clean: 3, excluded: 1, issues: 0 },
      rows: projectListResponse.rows.map((row) => ({
        ...row,
        status: 'Clean',
      })),
      summary: {
        ...projectListResponse.summary,
        issuesToResolve: 0,
      },
    };
    const readyToFinalizeSetup = {
      ...setupResponse,
      checklistItems: setupResponse.checklistItems.map((item) => {
        if (item.id === 'resolve-project-issues') {
          return { ...item, completed: true, status: 'done' };
        }

        if (item.id === 'finalize-projects') {
          return { ...item, ready: true, status: 'ready' };
        }

        return item;
      }),
      completedCount: 6,
    };
    const finalizedSetup = {
      ...readyToFinalizeSetup,
      checklistItems: readyToFinalizeSetup.checklistItems.map((item) =>
        item.id === 'finalize-projects'
          ? { ...item, completed: true, status: 'done' }
          : item
      ),
      completedCount: 7,
    };

    server.use(
      http.get('/api/user/me', () => {
        return HttpResponse.json(mockUser);
      }),
      http.get('/api/imports/recent', () => {
        return HttpResponse.json([]);
      }),
      http.get('/api/projectidentification/setup', () => {
        return HttpResponse.json(
          finalizeRequests > 0 ? finalizedSetup : readyToFinalizeSetup
        );
      }),
      http.get('/api/projectlist', () => {
        return HttpResponse.json(cleanProjectList);
      }),
      http.post('/api/projectidentification/finalize', () => {
        finalizeRequests += 1;
        return HttpResponse.json(finalizedSetup);
      })
    );

    const { cleanup } = renderRoute({
      initialPath: '/workflow/project-identification',
    });

    try {
      const finalize = await screen.findByRole('button', {
        name: 'Finalize projects',
      });
      expect(finalize).toBeEnabled();

      await user.click(finalize);

      await waitFor(() => {
        expect(finalizeRequests).toBe(1);
        expect(screen.getByText('7 of 7 complete')).toBeInTheDocument();
      });
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
        await screen.findByRole('heading', {
          name: 'Project list · 3 active (1 excluded from associations)',
        })
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
