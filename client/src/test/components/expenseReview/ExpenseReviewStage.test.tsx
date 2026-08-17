import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { screen, waitFor, within } from '@testing-library/react';
import { createWorkflowSnapshot, server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';
import { userEvent } from '@testing-library/user-event';

const mockUser = {
  email: 'shannon@example.edu',
  id: 'user-1',
  name: 'Shannon Taylor',
  roles: ['User'],
};

const filtersResponse = {
  accountingPeriods: [{ label: 'Oct-25', value: 'Oct-25' }],
  accounts: [{ label: '500000 - Salaries', value: '500000' }],
  aeProjects: [{ label: 'K1234 - Tomato Project', value: 'K1234' }],
  financialDepts: [{ label: 'D0123 - Plant Sciences', value: 'D0123' }],
  funds: [{ label: '13U02 - Experiment Station', value: '13U02' }],
  sfns: [{ label: '220 - AES', value: '220' }],
  sources: [
    { label: 'AE', value: 'AE' },
    { label: 'UCP', value: 'UCP' },
  ],
};

const transactionRows = [
  {
    account: { code: '500000', name: 'Salaries' },
    accountingPeriod: 'Oct-25',
    aeProject: { code: 'K1234', name: 'Tomato Project' },
    amount: 1200.5,
    financialDept: { code: 'D0123', name: 'Plant Sciences' },
    fte: null,
    fteIncluded: false,
    fund: { code: '13U02', name: 'Experiment Station' },
    id: 'AE:100',
    included: true,
    sfn: '220',
    sfnLabel: 'AES',
    source: 'AE',
    sourceId: '100',
  },
  {
    account: { code: '500000', name: 'Salaries' },
    accountingPeriod: 'Oct-25',
    aeProject: { code: 'K1234', name: 'Tomato Project' },
    amount: 2400,
    financialDept: { code: 'D0123', name: 'Plant Sciences' },
    fte: 0.456,
    fteIncluded: true,
    fund: { code: '13U02', name: 'Experiment Station' },
    id: 'UCP:200',
    included: false,
    sfn: '220',
    sfnLabel: 'AES',
    source: 'UCP',
    sourceId: '200',
  },
];

function transactionsResponse(page = 1) {
  return {
    counts: { all: 2, excluded: 1, included: 1 },
    cycleEnd: '2026-09-30',
    cycleStart: '2025-10-01',
    fiscalYear: 'FY26',
    page,
    pageCount: 2,
    pageSize: 25,
    rows: transactionRows,
    totalCount: 2,
  };
}

function mockExpenseReviewApi(requests: URL[] = []) {
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
    http.get('/api/expensereview/filters', () =>
      HttpResponse.json(filtersResponse)
    ),
    http.get('/api/expensereview/transactions', ({ request }) => {
      const url = new URL(request.url);
      requests.push(url);
      return HttpResponse.json(
        transactionsResponse(Number(url.searchParams.get('page') ?? '1'))
      );
    })
  );
}

describe('Expense Review stage', () => {
  it('renders All Transactions instead of the placeholder with AE and UCPath rows', async () => {
    mockExpenseReviewApi();
    const { cleanup } = renderRoute({ initialPath: '/workflow/expense-review' });

    try {
      expect(
        await screen.findByRole('tab', { name: /all transactions/i })
      ).toBeInTheDocument();
      expect(
        screen.queryByRole('heading', { name: 'Coming soon' })
      ).not.toBeInTheDocument();
      expect(
        screen
          .getAllByText('AE')
          .find((element) => element.classList.contains('badge'))
      ).toHaveClass('badge-neutral');
      expect(
        screen
          .getAllByText('UCP')
          .find((element) => element.classList.contains('badge'))
      ).toHaveClass('badge-info');
      expect(screen.getByText('$1,200.50')).toBeInTheDocument();
      expect(screen.getByText('0.46')).toBeInTheDocument();

      const deptCode = screen.getAllByText('D0123')[0];
      expect(deptCode).toHaveAttribute('data-tip', 'Plant Sciences');
      expect(screen.getAllByText('220')[0]).toHaveAttribute('data-tip', 'AES');
    } finally {
      cleanup();
    }
  });

  it('refetches when include state, filters, sorting, and pagination change', async () => {
    const user = userEvent.setup();
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    const { cleanup } = renderRoute({ initialPath: '/workflow/expense-review' });

    try {
      await screen.findByRole('tab', { name: /all transactions/i });

      await user.click(screen.getByRole('button', { name: /Excluded/ }));
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('includeState')).toBe(
          'excluded'
        );
      });

      await user.selectOptions(screen.getByLabelText('Fund filter'), ['13U02']);
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.getAll('fund')).toEqual([
          '13U02',
        ]);
      });

      await user.click(screen.getByRole('button', { name: 'Clear all' }));
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.getAll('fund')).toEqual([]);
      });

      await user.click(
        screen.getByRole('columnheader', { name: /Financial Dept/ })
      );
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('sortBy')).toBe(
          'financialDept'
        );
      });

      await user.click(screen.getByRole('button', { name: 'Next' }));
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('page')).toBe('2');
      });
    } finally {
      cleanup();
    }
  });

  it('hides and restores controlled table columns', async () => {
    const user = userEvent.setup();
    mockExpenseReviewApi();
    const { cleanup } = renderRoute({ initialPath: '/workflow/expense-review' });

    try {
      await screen.findByRole('tab', { name: /all transactions/i });
      const table = screen.getByRole('table');
      expect(
        within(table).getByRole('columnheader', { name: 'Fund' })
      ).toBeInTheDocument();

      await user.click(screen.getByText('Columns'));
      const columnMenu = screen.getByText('Columns').closest('details')!;
      await user.click(within(columnMenu).getByLabelText('Fund'));

      expect(screen.getByText('6 of 7 shown')).toBeInTheDocument();
      expect(
        within(table).queryByRole('columnheader', { name: 'Fund' })
      ).not.toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: 'Show all' }));
      await waitFor(() => {
        expect(screen.getByText('7 of 7 shown')).toBeInTheDocument();
        expect(
          within(table).getByRole('columnheader', { name: 'Fund' })
        ).toBeInTheDocument();
      });
    } finally {
      cleanup();
    }
  });

  it('continues to Auto-Associations after completing the stage', async () => {
    const user = userEvent.setup();
    let updateRequests = 0;
    mockExpenseReviewApi();
    server.use(
      http.put('/api/workflow/stages/:stageId', async ({ params, request }) => {
        expect(params.stageId).toBe('expense-review');
        expect(await request.json()).toEqual({ status: 'Complete' });
        updateRequests += 1;
        return HttpResponse.json(
          createWorkflowSnapshot({
            'auto-associations': 'InProgress',
            'data-classification': 'Complete',
            'data-import': 'Complete',
            'expense-review': 'Complete',
            'project-identification': 'Complete',
          })
        );
      })
    );
    const { cleanup, router } = renderRoute({
      initialPath: '/workflow/expense-review',
    });

    try {
      await screen.findByRole('tab', { name: /all transactions/i });
      await user.click(
        screen.getByRole('button', { name: /continue to auto-associations/i })
      );

      await waitFor(() => {
        expect(updateRequests).toBe(1);
        expect(router.state.location.pathname).toBe(
          '/workflow/auto-associations'
        );
      });
    } finally {
      cleanup();
    }
  });

  it('shows loading and server error body states', async () => {
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
      http.get('/api/expensereview/filters', () =>
        HttpResponse.json(filtersResponse)
      ),
      http.get('/api/expensereview/transactions', () =>
        HttpResponse.json(
          { detail: 'No fiscal period has been confirmed.' },
          { status: 409 }
        )
      )
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/expense-review' });

    try {
      expect(
        await screen.findByText('Loading expense review transactions...')
      ).toBeInTheDocument();
      expect(
        await screen.findByText('No fiscal period has been confirmed.')
      ).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Retry' })).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });
});
