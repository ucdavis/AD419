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

describe('Data Classification stage', () => {
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
            'data-classification': 'InProgress',
            'data-import': 'Complete',
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
