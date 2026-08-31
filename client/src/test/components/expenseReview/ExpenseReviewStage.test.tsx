import { describe, expect, it, vi } from 'vitest';
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
  accountingPeriods: [{ label: 'Oct-24', value: 'Oct-24' }],
  accounts: [{ label: '500000 - Salaries', value: '500000' }],
  activities: [{ label: 'A100 - Research Activity', value: 'A100' }],
  aeProjects: [{ label: 'K1234 - Tomato Project', value: 'K1234' }],
  entities: [{ label: '3310 - UC Davis', value: '3310' }],
  exclusionReasons: [
    { label: 'Fund F2 excluded', value: 'fund:F2:excluded' },
  ],
  financialDepts: [{ label: 'D0123 - Plant Sciences', value: 'D0123' }],
  funds: [{ label: '13U02 - Experiment Station', value: '13U02' }],
  programs: [{ label: 'PG01 - Extension Program', value: 'PG01' }],
  purposes: [{ label: '44 - Research', value: '44' }],
  sfns: [{ label: '220 - AES', value: '220' }],
  sources: [
    { label: 'Aggie Enterprise', value: 'AE' },
    { label: 'UCPath', value: 'UCP' },
  ],
};

const transactionRows = [
  {
    account: { code: '500000', name: 'Salaries' },
    accountingPeriod: null,
    activity: { code: 'A100', name: 'Research Activity' },
    aeProject: { code: 'K1234', name: 'Tomato Project' },
    amount: 3600.5,
    entity: { code: '3310', name: 'UC Davis' },
    exclusionReasons: [],
    financialDept: { code: 'D0123', name: 'Plant Sciences' },
    fund: { code: '13U02', name: 'Experiment Station' },
    id: 'group-1',
    included: true,
    program: { code: 'PG01', name: 'Extension Program' },
    purpose: { code: '44', name: 'Research' },
    sfn: '220',
    sfnLabel: 'AES',
    source: 'AE',
  },
  {
    account: { code: '500000', name: 'Salaries' },
    accountingPeriod: null,
    activity: { code: 'A100', name: 'Research Activity' },
    aeProject: { code: 'K1234', name: 'Tomato Project' },
    amount: 2400,
    entity: { code: '3310', name: 'UC Davis' },
    exclusionReasons: [
      {
        amount: 2400,
        code: 'fund:F2:excluded',
        label: 'Fund F2 excluded',
        rowCount: 2,
      },
    ],
    financialDept: { code: 'D0123', name: 'Plant Sciences' },
    fund: { code: 'F2', name: 'Excluded Fund' },
    id: 'group-2',
    included: false,
    program: { code: 'PG01', name: 'Extension Program' },
    purpose: { code: '44', name: 'Research' },
    sfn: '220',
    sfnLabel: 'AES',
    source: 'UCP',
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

function mockExpenseReviewApi(requests: URL[] = [], exportRequests: URL[] = []) {
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
    }),
    http.get('/api/expensereview/transactions.csv', ({ request }) => {
      const url = new URL(request.url);
      exportRequests.push(url);
      return new HttpResponse(
        'Source,Entity,Fund,Financial Dept,Account,Purpose,Program,Project,Activity,SFN,Amount,Include State,Exclusion Reasons\r\n',
        {
          headers: {
            'Content-Disposition':
              "attachment; filename*=UTF-8''expense-review-transactions-fy26.csv",
            'Content-Type': 'text/csv',
          },
        }
      );
    })
  );
}

function mockCsvDownload() {
  const originalCreateObjectURL = URL.createObjectURL;
  const originalRevokeObjectURL = URL.revokeObjectURL;
  const createObjectURL = vi.fn(() => 'blob:expense-review');
  const revokeObjectURL = vi.fn();
  const click = vi
    .spyOn(HTMLAnchorElement.prototype, 'click')
    .mockImplementation(() => undefined);

  Object.defineProperty(URL, 'createObjectURL', {
    configurable: true,
    value: createObjectURL,
  });
  Object.defineProperty(URL, 'revokeObjectURL', {
    configurable: true,
    value: revokeObjectURL,
  });

  return {
    click,
    createObjectURL,
    restore: () => {
      if (originalCreateObjectURL) {
        Object.defineProperty(URL, 'createObjectURL', {
          configurable: true,
          value: originalCreateObjectURL,
        });
      } else {
        Reflect.deleteProperty(URL, 'createObjectURL');
      }

      if (originalRevokeObjectURL) {
        Object.defineProperty(URL, 'revokeObjectURL', {
          configurable: true,
          value: originalRevokeObjectURL,
        });
      } else {
        Reflect.deleteProperty(URL, 'revokeObjectURL');
      }

      click.mockRestore();
    },
    revokeObjectURL,
  };
}

describe('Expense Review stage', () => {
  it('renders grouped expense rows with full chart string columns and exclusion chips', async () => {
    mockExpenseReviewApi();
    const { cleanup } = renderRoute({ initialPath: '/workflow/expense-review' });

    try {
      expect(
        await screen.findByRole('tab', { name: /grouped expenses/i })
      ).toBeInTheDocument();

      const table = screen.getByRole('table');
      for (const header of [
        'Source',
        'Entity',
        'Fund',
        'Financial Dept',
        'Account',
        'Purpose',
        'Program',
        'Project',
        'Activity',
        'SFN',
        'Amount',
        'Include State',
        'Exclusion Reasons',
      ]) {
        expect(
          within(table).getByRole('columnheader', {
            name: new RegExp(`^${header}`),
          })
        ).toBeInTheDocument();
      }

      expect(screen.queryByText('Columns')).not.toBeInTheDocument();
      expect(screen.queryByText(/shown/i)).not.toBeInTheDocument();
      expect(
        within(table).queryByRole('columnheader', {
          name: /^Accounting Period/,
        })
      ).not.toBeInTheDocument();
      expect(screen.getByLabelText('Display by period')).not.toBeChecked();
      expect(screen.getByText('AE')).toBeInTheDocument();
      expect(screen.getByText('UCP')).toBeInTheDocument();
      expect(screen.getByText('$3,600.50')).toBeInTheDocument();
      expect(
        screen.getByText('Fund F2 excluded · $2,400.00 · 2 rows')
      ).toBeInTheDocument();

      expect(screen.getAllByText('3310')[0]).toHaveAttribute(
        'data-tip',
        'UC Davis'
      );
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
      await screen.findByRole('tab', { name: /grouped expenses/i });
      expect(requests.at(-1)?.searchParams.get('displayByPeriod')).toBe(
        'false'
      );

      await user.selectOptions(screen.getByLabelText('Include State filter'), [
        'excluded',
      ]);
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

      await user.selectOptions(screen.getByLabelText('Source filter'), ['AE']);
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.getAll('source')).toEqual(['AE']);
      });

      await user.selectOptions(screen.getByLabelText('Accounting Period filter'), [
        'Oct-24',
      ]);
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.getAll('accountingPeriod')).toEqual(
          ['Oct-24']
        );
      });

      await user.selectOptions(screen.getByLabelText('Exclusion Reason filter'), [
        'fund:F2:excluded',
      ]);
      await waitFor(() => {
        expect(
          requests.at(-1)?.searchParams.getAll('exclusionReason')
        ).toEqual(['fund:F2:excluded']);
      });

      await user.click(screen.getByRole('button', { name: 'Clear all' }));
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('includeState')).toBe('all');
        expect(requests.at(-1)?.searchParams.getAll('fund')).toEqual([]);
        expect(requests.at(-1)?.searchParams.getAll('source')).toEqual([]);
        expect(requests.at(-1)?.searchParams.getAll('accountingPeriod')).toEqual(
          []
        );
        expect(requests.at(-1)?.searchParams.getAll('exclusionReason')).toEqual(
          []
        );
      });

      await user.click(
        screen.getByRole('columnheader', { name: /Financial Dept/ })
      );
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('sortBy')).toBe(
          'financialDept'
        );
        expect(requests.at(-1)?.searchParams.get('sortDirection')).toBe('asc');
      });

      await user.click(
        screen.getByRole('columnheader', { name: /Financial Dept/ })
      );
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('sortBy')).toBe(
          'financialDept'
        );
        expect(requests.at(-1)?.searchParams.get('sortDirection')).toBe(
          'desc'
        );
      });

      await user.click(
        screen.getByRole('columnheader', { name: /Financial Dept/ })
      );
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('sortBy')).toBe('source');
        expect(requests.at(-1)?.searchParams.get('sortDirection')).toBe('asc');
      });

      await user.click(screen.getByRole('button', { name: 'Next' }));
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('page')).toBe('2');
      });
    } finally {
      cleanup();
    }
  });

  it('toggles period display and resets period sorting when turned off', async () => {
    const user = userEvent.setup();
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    const { cleanup } = renderRoute({ initialPath: '/workflow/expense-review' });

    try {
      await screen.findByRole('tab', { name: /grouped expenses/i });
      expect(
        within(screen.getByRole('table')).queryByRole('columnheader', {
          name: /^Accounting Period/,
        })
      ).not.toBeInTheDocument();

      await user.click(screen.getByLabelText('Display by period'));
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('displayByPeriod')).toBe(
          'true'
        );
      });
      expect(
        within(screen.getByRole('table')).getByRole('columnheader', {
          name: /^Accounting Period/,
        })
      ).toBeInTheDocument();

      await user.click(
        screen.getByRole('columnheader', { name: /Accounting Period/ })
      );
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('sortBy')).toBe(
          'accountingPeriod'
        );
      });

      await user.click(screen.getByLabelText('Display by period'));
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('displayByPeriod')).toBe(
          'false'
        );
        expect(requests.at(-1)?.searchParams.get('sortBy')).toBe('source');
      });
      expect(
        within(screen.getByRole('table')).queryByRole('columnheader', {
          name: /^Accounting Period/,
        })
      ).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('exports CSV with current filters and sort without column parameters', async () => {
    const user = userEvent.setup();
    const exportRequests: URL[] = [];
    const download = mockCsvDownload();
    mockExpenseReviewApi([], exportRequests);
    const { cleanup } = renderRoute({ initialPath: '/workflow/expense-review' });

    try {
      await screen.findByRole('tab', { name: /grouped expenses/i });

      await user.selectOptions(screen.getByLabelText('Include State filter'), [
        'excluded',
      ]);
      await user.selectOptions(screen.getByLabelText('Fund filter'), ['13U02']);
      await user.click(screen.getByLabelText('Display by period'));
      await user.click(
        screen.getByRole('columnheader', { name: /Financial Dept/ })
      );
      await user.click(screen.getByRole('button', { name: 'Export CSV' }));

      await waitFor(() => {
        expect(exportRequests).toHaveLength(1);
        expect(download.createObjectURL).toHaveBeenCalled();
        expect(download.click).toHaveBeenCalled();
      });

      const exportUrl = exportRequests[0];
      expect(exportUrl.searchParams.get('includeState')).toBe('excluded');
      expect(exportUrl.searchParams.get('displayByPeriod')).toBe('true');
      expect(exportUrl.searchParams.getAll('fund')).toEqual(['13U02']);
      expect(exportUrl.searchParams.get('sortBy')).toBe('financialDept');
      expect(exportUrl.searchParams.get('sortDirection')).toBe('asc');
      expect(exportUrl.searchParams.get('page')).toBeNull();
      expect(exportUrl.searchParams.get('pageSize')).toBeNull();
      expect(exportUrl.searchParams.getAll('column')).toEqual([]);
    } finally {
      cleanup();
      download.restore();
    }
  });

  it('shows export failure text', async () => {
    const user = userEvent.setup();
    const download = mockCsvDownload();
    mockExpenseReviewApi();
    server.use(
      http.get('/api/expensereview/transactions.csv', () =>
        new HttpResponse(JSON.stringify({ detail: 'CSV export failed.' }), {
          headers: { 'Content-Type': 'application/problem+json' },
          status: 500,
        })
      )
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/expense-review' });

    try {
      await screen.findByRole('tab', { name: /grouped expenses/i });
      await user.click(screen.getByRole('button', { name: 'Export CSV' }));

      expect(await screen.findByText('CSV export failed.')).toBeInTheDocument();
      expect(download.click).not.toHaveBeenCalled();
    } finally {
      cleanup();
      download.restore();
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
      await screen.findByRole('tab', { name: /grouped expenses/i });
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
