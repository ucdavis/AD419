import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { screen, waitFor } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { createWorkflowSnapshot, server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';

const mockUser = {
  email: 'shannon@example.edu',
  id: 'user-1',
  name: 'Shannon Taylor',
  roles: ['User'],
};

const completedUpstream = {
  'auto-associations': 'InProgress',
  'data-classification': 'Complete',
  'data-import': 'Complete',
  'expense-review': 'Complete',
  'orgr-review': 'Complete',
  'project-identification': 'Complete',
} as const;

const envelope = <T,>(data: T) => ({
  cycleEnd: '2025-09-30',
  cycleStart: '2024-10-01',
  data,
  fiscalYear: 'FY25',
});

const build = {
  associationRows: 11,
  buildId: 1,
  builtAt: '2026-07-07T12:00:00Z',
  cycleEnd: '2025-09-30',
  cycleStart: '2024-10-01',
  excludedProjects: 2,
  misclassified204Rows: 1,
  summaryRows: 9,
};

function mockApi(options: { completeFails?: boolean; failingReport?: boolean; hasBuild: boolean; }) {
  server.use(
    http.get('/api/user/me', () => HttpResponse.json(mockUser)),
    http.get('/api/workflow/snapshot', () =>
      HttpResponse.json(createWorkflowSnapshot(completedUpstream))
    ),
    http.get('/api/autoassociations/build', () =>
      HttpResponse.json(envelope(options.hasBuild ? build : null))
    ),
    http.get('/api/autoassociations/rule-204', () =>
      HttpResponse.json(
        envelope({
          misclassified: [],
          projects: [
            {
              accessionNumber: '1000001',
              aeProjects: 'AE-A',
              expenses: 500,
              fte: 0,
              nifaProjectNumber: 'CA-D-ABC-1001-CG',
              projectDirector: 'PI One',
              title: 'Shared grant A',
            },
          ],
          unassociated: [
            {
              employeeId: null,
              employeeName: null,
              expenseId: 7,
              expenses: 80,
              expenseSfn: '204',
              financialDepartment: 'D1',
              fte: 0,
              fund: 'F204',
              orgR: 'AAAA',
              project: 'AE-S',
              reason: 'ProjectExcluded',
              source: 'AE',
            },
          ],
        })
      )
    ),
    http.get('/api/autoassociations/rule-20x', () =>
      HttpResponse.json(
        envelope({
          sfns: [
            {
              expenses: 660,
              fte: 0.66,
              label: 'Hatch',
              pis: [{ employeeId: 'E1', employeeName: 'PI One', expenses: 600, fte: 0.6, projectCount: 2 }],
              projectCount: 3,
              sfn: '201',
            },
            { expenses: 0, fte: 0, label: null, pis: [], projectCount: 0, sfn: '202' },
            { expenses: 0, fte: 0, label: null, pis: [], projectCount: 0, sfn: '205' },
          ],
          unassociated: [],
        })
      )
    ),
    http.get('/api/autoassociations/rule-220', () =>
      options.failingReport
        ? HttpResponse.text('boom', { status: 500 })
        : HttpResponse.json(
            envelope({
              projects: [
                {
                  accessionNumber: '1000003',
                  aeProjects: null,
                  expenses: 135,
                  fte: 0.125,
                  nifaProjectNumber: 'CA-D-ABC-1003-H',
                  projectDirector: 'PI One',
                  title: 'Hatch one',
                },
              ],
              unassociated: [],
            })
          )
    ),
    http.get('/api/autoassociations/excluded-projects', () =>
      HttpResponse.json(
        envelope([
          {
            accessionNumber: '1000010',
            aeProjects: 'AE-S',
            nifaProjectNumber: 'CA-D-ABC-1010-CG',
            projectDirector: 'PI Seven',
            title: 'Small grant',
            total: 80,
          },
        ])
      )
    ),
    http.get('/api/autoassociations/fte-over-one', () =>
      HttpResponse.json(
        envelope([{ employeeId: 'E1', employeeName: 'PI One', fte: 1.3, rowCount: 3 }])
      )
    ),
    http.get('/api/autoassociations/pre-association-totals', () =>
      HttpResponse.json(
        envelope([
          {
            expenses: 1457,
            expenseSfn: '204',
            financialDepartment: 'D1',
            financialDepartmentName: 'Dept One',
            fte: 0,
            orgR: 'AAAA',
            sfnLabel: 'Grants',
          },
        ])
      )
    ),
    http.get('/api/ExpenseReview/unmatched-job-codes', () =>
      HttpResponse.json({
        cycleEnd: '2025-09-30',
        cycleStart: '2024-10-01',
        fiscalYear: 'FY25',
        rows: [
          {
            amount: 12.5,
            employeeCount: 1,
            fte: 0.05,
            jobCode: '9999',
            reason: 'noTitle',
            rowCount: 1,
            staffTypeCode: null,
            titleName: null,
          },
        ],
      })
    ),
    http.put('/api/workflow/stages/auto-associations', () =>
      options.completeFails
        ? HttpResponse.text('The workflow stage cannot be updated in its current state.', { status: 400 })
        : HttpResponse.json(
            createWorkflowSnapshot({ ...completedUpstream, 'auto-associations': 'Complete' })
          )
    )
  );
}

describe('Auto-Associations stage', () => {
  it('shows the empty state and a disabled Continue when there is no build', async () => {
    mockApi({ hasBuild: false });
    const { cleanup } = renderRoute({ initialPath: '/workflow/auto-associations' });

    try {
      expect(
        await screen.findByText(
          'No auto-association build exists for this cycle. Reopen OrgR Review and mark it complete to build.'
        )
      ).toBeInTheDocument();
      expect(
        screen.getByRole('button', { name: /Continue to Manual Associations/ })
      ).toBeDisabled();
      expect(screen.queryByRole('tab')).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('renders the report tabs from a build and continues to Manual Associations', async () => {
    mockApi({ hasBuild: true });
    const user = userEvent.setup();
    const { cleanup, router } = renderRoute({ initialPath: '/workflow/auto-associations' });

    try {
      expect(await screen.findByRole('tab', { name: /204/ })).toHaveAttribute('aria-selected', 'true');
      expect(await screen.findByText('Shared grant A')).toBeInTheDocument();
      expect(screen.getByText('AE-S')).toBeInTheDocument();
      expect(screen.getByText('ProjectExcluded')).toBeInTheDocument();

      await user.click(screen.getByRole('tab', { name: /Under \$100/ }));
      expect(await screen.findByText('Small grant')).toBeInTheDocument();

      const continueButton = screen.getByRole('button', { name: /Continue to Manual Associations/ });
      expect(continueButton).toBeEnabled();
      await user.click(continueButton);
      await waitFor(() =>
        expect(router.state.location.pathname).toBe('/workflow/manual-associations')
      );
    } finally {
      cleanup();
    }
  });

  it('shows the server message when completing fails', async () => {
    mockApi({ completeFails: true, hasBuild: true });
    const user = userEvent.setup();
    const { cleanup } = renderRoute({ initialPath: '/workflow/auto-associations' });

    try {
      await screen.findByRole('tab', { name: /204/ });
      await user.click(screen.getByRole('button', { name: /Continue to Manual Associations/ }));
      const alerts = await screen.findAllByRole('alert');
      expect(
        alerts.some((el) => el.textContent?.includes('The workflow stage cannot be updated in its current state.'))
      ).toBe(true);
    } finally {
      cleanup();
    }
  });

  it('loads each report tab', async () => {
    mockApi({ hasBuild: true });
    const user = userEvent.setup();
    const { cleanup } = renderRoute({ initialPath: '/workflow/auto-associations' });

    try {
      await screen.findByRole('tab', { name: /204/ });

      await user.click(screen.getByRole('tab', { name: '201 / 202 / 205' }));
      expect(await screen.findByText('PI One')).toBeInTheDocument();
      expect(
        (await screen.findAllByRole('heading')).some((el) => el.textContent?.includes('$660.00'))
      ).toBe(true);

      await user.click(screen.getByRole('tab', { name: '220' }));
      expect(await screen.findByText('Hatch one')).toBeInTheDocument();

      await user.click(screen.getByRole('tab', { name: 'FTE over 1.0' }));
      expect(await screen.findByText('1.300')).toBeInTheDocument();

      await user.click(screen.getByRole('tab', { name: 'Pre-association totals' }));
      expect(await screen.findByText('Dept One')).toBeInTheDocument();

      await user.click(screen.getByRole('tab', { name: 'Unmatched job codes' }));
      expect(await screen.findByText('9999')).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('shows a report error inside the tab', async () => {
    mockApi({ failingReport: true, hasBuild: true });
    const user = userEvent.setup();
    const { cleanup } = renderRoute({ initialPath: '/workflow/auto-associations' });

    try {
      await screen.findByRole('tab', { name: /204/ });
      await user.click(screen.getByRole('tab', { name: '220' }));
      const alerts = await screen.findAllByRole('alert');
      expect(alerts.some((el) => el.textContent?.includes('boom'))).toBe(true);
    } finally {
      cleanup();
    }
  });
});
