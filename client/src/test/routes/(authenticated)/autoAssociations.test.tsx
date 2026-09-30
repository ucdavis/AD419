import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { screen } from '@testing-library/react';
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

function mockApi(options: { completeFails?: boolean; hasBuild: boolean; }) {
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
      HttpResponse.json(envelope({ sfns: [], unassociated: [] }))
    ),
    http.get('/api/autoassociations/rule-220', () =>
      HttpResponse.json(envelope({ projects: [], unassociated: [] }))
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
      HttpResponse.json(envelope([]))
    ),
    http.get('/api/autoassociations/pre-association-totals', () =>
      HttpResponse.json(envelope([]))
    ),
    http.get('/api/ExpenseReview/unmatched-job-codes', () =>
      HttpResponse.json({
        cycleEnd: '2025-09-30',
        cycleStart: '2024-10-01',
        fiscalYear: 'FY25',
        rows: [],
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

  it('shows the server message when completing fails', async () => {
    mockApi({ completeFails: true, hasBuild: true });
    const user = userEvent.setup();
    const { cleanup } = renderRoute({ initialPath: '/workflow/auto-associations' });

    try {
      await screen.findByRole('tab', { name: /204/ });
      await user.click(screen.getByRole('button', { name: /Continue to Manual Associations/ }));
      expect(await screen.findByRole('alert')).toHaveTextContent(
        'The workflow stage cannot be updated in its current state.'
      );
    } finally {
      cleanup();
    }
  });
});
