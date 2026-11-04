import { QueryClient } from '@tanstack/react-query';
import { buildExpenseReviewClientTools } from '@/components/expenseReview/expenseReviewAssistantTools.ts';
import { resolveExpenseReviewView } from '@/components/expenseReview/expenseReviewSearch.ts';
import {
  expenseReviewTransactionsQueryOptions,
  type ExpenseReviewTransaction,
} from '@/queries/expenseReview.ts';
import { describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';
import { act, screen, waitFor, within } from '@testing-library/react';
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
  exclusionReasons: [{ label: 'Excluded by fund', value: 'fund:excluded' }],
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

const transactionRows: ExpenseReviewTransaction[] = [
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
        code: 'fund:excluded',
        label: 'Excluded by fund',
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
    totalAmount: 6000.5,
    totalCount: 2,
  };
}

function mockExpenseReviewApi(
  requests: URL[] = [],
  exportRequests: URL[] = []
) {
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

async function chooseFilterOption(
  user: ReturnType<typeof userEvent.setup>,
  label: string,
  option: string
) {
  await user.click(screen.getByLabelText(`${label} filter`));
  await user.click(screen.getByRole('option', { name: option }));
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
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true',
    });

    try {
      expect(
        await screen.findByRole('tab', { name: /grouped expenses/i })
      ).toBeInTheDocument();

      const table = await screen.findByRole('table');
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
      expect(screen.getByLabelText('Include $0 groups')).not.toBeChecked();
      expect(screen.getByText('AE')).toBeInTheDocument();
      expect(screen.getByText('UCP')).toBeInTheDocument();
      expect(screen.getByText('$3,600.50')).toBeInTheDocument();
      // Reason chips show only the label, without amount or row count.
      expect(
        screen
          .getAllByText('Excluded by fund')
          .some((element) => element.classList.contains('badge'))
      ).toBe(true);
      expect(screen.queryByText(/Excluded by fund ·/)).not.toBeInTheDocument();

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
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true',
    });

    try {
      await screen.findByRole('table');
      expect(requests.at(-1)?.searchParams.get('displayByPeriod')).toBe(
        'false'
      );
      expect(requests.at(-1)?.searchParams.get('includeZeroAmounts')).toBe(
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

      await chooseFilterOption(user, 'Fund', '13U02 - Experiment Station');
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.getAll('fund')).toEqual(['13U02']);
      });
      expect(
        screen.getByRole('button', {
          name: 'Fund: 13U02 - Experiment Station',
        })
      ).toBeInTheDocument();

      await chooseFilterOption(user, 'Source', 'Aggie Enterprise');
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.getAll('source')).toEqual(['AE']);
      });

      await chooseFilterOption(user, 'Accounting Period', 'Oct-24');
      await waitFor(() => {
        expect(
          requests.at(-1)?.searchParams.getAll('accountingPeriod')
        ).toEqual(['Oct-24']);
      });

      await chooseFilterOption(user, 'Exclusion Reason', 'Excluded by fund');
      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.getAll('exclusionReason')).toEqual(
          ['fund:excluded']
        );
      });
      expect(
        screen.getByRole('button', {
          name: 'Exclusion Reason: Excluded by fund',
        })
      ).toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: 'Clear all' }));
      expect(
        await screen.findByText('Select a filter or load all expenses')
      ).toBeInTheDocument();
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
      await user.click(
        screen.getByRole('button', { name: 'Load all expenses' })
      );
      await screen.findByRole('table');
      expect(requests.at(-1)?.searchParams.get('includeState')).toBe('all');
      expect(requests.at(-1)?.searchParams.getAll('fund')).toEqual([]);

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
        expect(requests.at(-1)?.searchParams.get('sortDirection')).toBe('desc');
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

  it('requests zero-amount groups only when enabled', async () => {
    const user = userEvent.setup();
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true',
    });

    try {
      await screen.findByRole('table');
      await user.click(screen.getByLabelText('Include $0 groups'));

      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('includeZeroAmounts')).toBe(
          'true'
        );
        expect(requests.at(-1)?.searchParams.get('page')).toBe('1');
      });
    } finally {
      cleanup();
    }
  });

  it('toggles period display and resets period sorting when turned off', async () => {
    const user = userEvent.setup();
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true',
    });

    try {
      await screen.findByRole('table');
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
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true',
    });

    try {
      await screen.findByRole('table');

      await user.selectOptions(screen.getByLabelText('Include State filter'), [
        'excluded',
      ]);
      await chooseFilterOption(user, 'Fund', '13U02 - Experiment Station');
      await user.click(screen.getByLabelText('Display by period'));
      await user.click(screen.getByLabelText('Include $0 groups'));
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
      expect(exportUrl.searchParams.get('includeZeroAmounts')).toBe('true');
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
      http.get(
        '/api/expensereview/transactions.csv',
        () =>
          new HttpResponse(JSON.stringify({ detail: 'CSV export failed.' }), {
            headers: { 'Content-Type': 'application/problem+json' },
            status: 500,
          })
      )
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true',
    });

    try {
      await screen.findByRole('table');
      await user.click(screen.getByRole('button', { name: 'Export CSV' }));

      expect(await screen.findByText('CSV export failed.')).toBeInTheDocument();
      expect(download.click).not.toHaveBeenCalled();
    } finally {
      cleanup();
      download.restore();
    }
  });

  it.each(['InProgress', 'Complete'] as const)(
    'continues to OrgR Review when its status is %s',
    async (orgRStatus) => {
      const user = userEvent.setup();
      let updateRequests = 0;
      mockExpenseReviewApi();
      server.use(
        http.get('/api/orgr/financial-departments', () =>
          HttpResponse.json([])
        ),
        http.get('/api/orgr/nifa-departments', () => HttpResponse.json([])),
        http.get('/api/orgr/orgrs', () => HttpResponse.json([])),
        http.put(
          '/api/workflow/stages/:stageId',
          async ({ params, request }) => {
            expect(params.stageId).toBe('expense-review');
            expect(await request.json()).toEqual({ status: 'Complete' });
            updateRequests += 1;
            return HttpResponse.json(
              createWorkflowSnapshot({
                'data-classification': 'Complete',
                'data-import': 'Complete',
                'expense-review': 'Complete',
                'orgr-review': orgRStatus,
                'project-identification': 'Complete',
              })
            );
          }
        )
      );
      const { cleanup, router } = renderRoute({
        initialPath: '/workflow/expense-review',
      });

      try {
        await screen.findByText('Select a filter or load all expenses');
        await user.click(
          screen.getByRole('button', { name: /continue to orgr review/i })
        );

        await waitFor(() => {
          expect(updateRequests).toBe(1);
          expect(router.state.location.pathname).toBe('/workflow/orgr-review');
        });
      } finally {
        cleanup();
      }
    }
  );

  it('hydrates filters, include state, sort, and paging from the URL', async () => {
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    const { cleanup } = renderRoute({
      initialPath:
        '/workflow/expense-review?fund=%5B%2213U02%22%5D&include=excluded&sort=amount&dir=desc&page=2&size=50&zero=true',
    });

    try {
      await screen.findByRole('table');
      const last = requests.at(-1)!.searchParams;
      expect(last.getAll('fund')).toEqual(['13U02']);
      expect(last.get('includeState')).toBe('excluded');
      expect(last.get('sortBy')).toBe('amount');
      expect(last.get('sortDirection')).toBe('desc');
      expect(last.get('page')).toBe('2');
      expect(last.get('pageSize')).toBe('50');
      expect(last.get('includeZeroAmounts')).toBe('true');
      expect(
        screen.getByRole('button', { name: 'Fund: 13U02 - Experiment Station' })
      ).toBeInTheDocument();
      expect(screen.getByLabelText('Include $0 groups')).toBeChecked();
    } finally {
      cleanup();
    }
  });

  it('narrows filter dropdowns to options valid for the current selections', async () => {
    const user = userEvent.setup();
    const filterRequests: URL[] = [];
    mockExpenseReviewApi();
    server.use(
      http.get('/api/expensereview/filters', ({ request }) => {
        const url = new URL(request.url);
        filterRequests.push(url);
        const byDept = url.searchParams.getAll('financialDept').length > 0;
        return HttpResponse.json({
          ...filtersResponse,
          financialDepts: [
            ...filtersResponse.financialDepts,
            { label: 'D0999 - Other Dept', value: 'D0999' },
          ],
          funds: byDept
            ? filtersResponse.funds
            : [
                ...filtersResponse.funds,
                { label: 'F9 - Other Fund', value: 'F9' },
              ],
        });
      })
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true',
    });

    try {
      await screen.findByRole('table');
      await user.click(screen.getByLabelText('Fund filter'));
      expect(
        screen.getByRole('option', { name: 'F9 - Other Fund' })
      ).toBeInTheDocument();
      await user.keyboard('{Escape}');

      await chooseFilterOption(
        user,
        'Financial Dept',
        'D0123 - Plant Sciences'
      );
      await waitFor(() => {
        expect(
          filterRequests.at(-1)?.searchParams.getAll('financialDept')
        ).toEqual(['D0123']);
      });
      await waitFor(() => {
        expect(screen.getByLabelText('Fund filter')).toBeEnabled();
      });

      await user.click(screen.getByLabelText('Fund filter'));
      expect(
        screen.getByRole('option', { name: '13U02 - Experiment Station' })
      ).toBeInTheDocument();
      expect(
        screen.queryByRole('option', { name: 'F9 - Other Fund' })
      ).not.toBeInTheDocument();
      expect(
        screen.getByRole('tab', { name: /grouped expenses/i })
      ).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('writes filter changes to the URL and resets the page', async () => {
    const user = userEvent.setup();
    mockExpenseReviewApi();
    const { cleanup, router } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true&page=2',
    });

    try {
      await screen.findByRole('table');
      await chooseFilterOption(user, 'Fund', '13U02 - Experiment Station');

      await waitFor(() => {
        expect(router.state.location.search).toEqual({ fund: ['13U02'] });
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
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true',
    });

    try {
      expect(
        await screen.findByText('No fiscal period has been confirmed.')
      ).toBeInTheDocument();
      expect(
        screen.getByRole('button', { name: 'Retry expenses' })
      ).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });
});

function completion() {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

describe('Expense Review loading eligibility', () => {
  it.each([false, true])(
    'stays idle with cached unfiltered results: %s',
    async (cached) => {
      const requests: URL[] = [];
      mockExpenseReviewApi(requests);
      const queryClient = new QueryClient({
        defaultOptions: { queries: { retry: false } },
      });
      if (cached) {
        const view = resolveExpenseReviewView({});
        queryClient.setQueryData(
          expenseReviewTransactionsQueryOptions({
            displayByPeriod: view.displayByPeriod,
            filters: view.filters,
            includeState: view.includeState,
            includeZeroAmounts: view.includeZeroAmounts,
            page: view.page,
            pageSize: view.pageSize,
            sortBy: view.sortBy,
            sortDirection: view.sortDirection,
          }).queryKey,
          transactionsResponse()
        );
      }
      const { cleanup, router } = renderRoute({
        initialPath: '/workflow/expense-review',
        queryClient,
      });
      try {
        await screen.findByText('Select a filter or load all expenses');
        expect(screen.queryByRole('table')).not.toBeInTheDocument();
        expect(screen.queryByText(/grouped rows/)).not.toBeInTheDocument();
        expect(
          within(screen.getByLabelText('Include State filter')).getByRole('option', {
            name: 'All',
          })
        ).toBeInTheDocument();
        expect(
          screen.getByRole('tab', { name: 'Grouped Expenses' })
        ).toBeInTheDocument();
        expect(
          screen.getByRole('button', { name: 'Export CSV' })
        ).toBeDisabled();
        const user = userEvent.setup();
        await user.click(screen.getByLabelText('Display by period'));
        await user.click(screen.getByLabelText('Include $0 groups'));
        expect(requests).toHaveLength(0);
        await user.click(
          screen.getByRole('button', { name: 'Load all expenses' })
        );
        await screen.findByRole('table');
        expect(router.state.location.search.loadAll).toBe(true);
        expect(requests.at(-1)?.searchParams.has('loadAll')).toBe(false);
        await user.click(screen.getByRole('button', { name: 'Next' }));
        await waitFor(() => expect(router.state.location.search.page).toBe(2));
        expect(router.state.location.search.loadAll).toBe(true);
        await screen.findByRole('table');
        await user.click(
          screen.getByRole('columnheader', { name: /Financial Dept/ })
        );
        await waitFor(() =>
          expect(router.state.location.search.sort).toBe('financialDept')
        );
        expect(router.state.location.search.loadAll).toBe(true);
      } finally {
        cleanup();
      }
    }
  );

  it.each([
    ['account', ['500000']],
    ['accountingPeriod', ['Oct-24']],
    ['activity', ['A100']],
    ['aeProject', ['K1234']],
    ['entity', ['3310']],
    ['exclusionReason', ['fund:excluded']],
    ['financialDept', ['D0123']],
    ['fund', ['13U02']],
    ['program', ['PG01']],
    ['purpose', ['44']],
    ['sfn', ['220']],
    ['source', ['AE']],
    ['include', 'included'],
    ['include', 'excluded'],
  ])('loads automatically from a %s deep link (%j)', async (key, value) => {
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    const search = new URLSearchParams({
      [key as string]:
        typeof value === 'string' ? value : JSON.stringify(value),
    });
    const { cleanup } = renderRoute({
      initialPath: `/workflow/expense-review?${search}`,
    });
    try {
      await screen.findByRole('table');
      expect(requests).toHaveLength(1);
      expect(
        screen.queryByText('Select a filter or load all expenses')
      ).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it.each(['loadAll=false', 'loadAll=invalid', 'include=all', 'source=%5B%5D'])(
    'ignores non-qualifying search %s',
    async (search) => {
      const requests: URL[] = [];
      mockExpenseReviewApi(requests);
      const { cleanup } = renderRoute({
        initialPath: `/workflow/expense-review?${search}`,
      });
      try {
        await screen.findByText('Select a filter or load all expenses');
        expect(requests).toHaveLength(0);
      } finally {
        cleanup();
      }
    }
  );

  it('restores explicit loading from a refreshed URL and clears it when the last filter is removed', async () => {
    mockExpenseReviewApi();
    const user = userEvent.setup();
    const first = renderRoute({
      initialPath: '/workflow/expense-review?page=2',
    });
    await user.click(
      await screen.findByRole('button', { name: 'Load all expenses' })
    );
    await screen.findByRole('table');
    expect(first.router.state.location.search.page).toBeUndefined();
    const refreshedPath = first.router.state.location.href;
    first.cleanup();
    const { cleanup, router } = renderRoute({ initialPath: refreshedPath });
    try {
      await screen.findByRole('table');
      await chooseFilterOption(user, 'Source', 'Aggie Enterprise');
      await waitFor(() =>
        expect(router.state.location.search.loadAll).toBeUndefined()
      );
      await user.click(
        screen.getByRole('button', { name: 'Source: Aggie Enterprise' })
      );
      await screen.findByText('Select a filter or load all expenses');
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('shows all expenses through the assistant and clears back to idle with cached results', async () => {
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    const { cleanup, queryClient, router } = renderRoute({
      initialPath:
        '/workflow/expense-review?byPeriod=true&dir=desc&page=3&size=50&sort=amount&zero=true',
    });
    try {
      await screen.findByText('Select a filter or load all expenses');
      expect(requests).toHaveLength(0);
      let navigation: Promise<unknown> = Promise.resolve();
      const tools = buildExpenseReviewClientTools({
        getSearch: () => router.state.location.search,
        setSearch: (patch) => {
          navigation = router.navigate({
            search: { ...router.state.location.search, ...patch },
            to: '.',
          });
        },
      });
      const setFilters = tools.find(
        (candidate) => candidate.name === 'set_expense_review_filters'
      )!;
      const getView = tools.find(
        (candidate) => candidate.name === 'get_expense_review_view'
      )!;

      await act(async () => {
        expect(
          setFilters.execute({ includeState: 'all', loadAll: true })
        ).toMatchObject({ loadAll: true });
        await navigation;
      });
      await screen.findByRole('table');
      expect(requests).toHaveLength(1);
      const params = requests[0].searchParams;
      expect(params.get('includeState')).toBe('all');
      expect(params.get('page')).toBe('1');
      expect(params.has('loadAll')).toBe(false);
      for (const key of Object.keys(resolveExpenseReviewView({}).filters)) {
        expect(params.has(key)).toBe(false);
      }
      expect(router.state.location.search).toMatchObject({
        byPeriod: true,
        dir: 'desc',
        loadAll: true,
        size: 50,
        sort: 'amount',
        zero: true,
      });
      expect(router.state.location.search.page).toBeUndefined();
      expect(getView.execute({})).toMatchObject({ loadAll: true });
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeEnabled();

      await act(async () => {
        expect(setFilters.execute({})).toMatchObject({ loadAll: false });
        await navigation;
      });
      await screen.findByText('Select a filter or load all expenses');
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeDisabled();
      expect(requests).toHaveLength(1);
      expect(getView.execute({})).toMatchObject({ loadAll: false });
      const cached = queryClient.getQueriesData({
        queryKey: ['expenseReview', 'transactions'],
      });
      const cachedResults = cached
        .map(([, data]) => data)
        .filter((data) => data !== undefined);
      expect(cachedResults).toEqual([transactionsResponse()]);
    } finally {
      cleanup();
    }
  });

  it('applies assistant filters and clears back to idle through the same URL helper', async () => {
    mockExpenseReviewApi();
    const { cleanup, router } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true&page=2',
    });
    try {
      await screen.findByRole('table');
      let navigation: Promise<unknown> = Promise.resolve();
      const tools = buildExpenseReviewClientTools({
        getSearch: () => router.state.location.search,
        setSearch: (patch) => {
          navigation = router.navigate({
            search: { ...router.state.location.search, ...patch },
            to: '.',
          });
        },
      });
      const tool = tools.find(
        (candidate) => candidate.name === 'set_expense_review_filters'
      )!;
      await act(async () => {
        tool.execute({ source: ['AE'] });
        await navigation;
      });
      await screen.findByRole('table');
      expect(router.state.location.search.loadAll).toBeUndefined();
      expect(router.state.location.search.page).toBeUndefined();
      await act(async () => {
        tool.execute({});
        await navigation;
      });
      await screen.findByText('Select a filter or load all expenses');
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('keeps controls and code chips visible while options and expenses load independently', async () => {
    mockExpenseReviewApi();
    const options = completion();
    const expenses = completion();
    server.use(
      http.get('/api/expensereview/filters', async () => {
        await options.promise;
        return HttpResponse.json(filtersResponse);
      }),
      http.get('/api/expensereview/transactions', async () => {
        await expenses.promise;
        return HttpResponse.json(transactionsResponse());
      })
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?source=%5B%22AE%22%5D',
    });
    try {
      await screen.findByText('Loading expense review transactions...');
      expect(screen.getByLabelText('Include State filter')).toBeEnabled();
      expect(screen.getByLabelText('Display by period')).toBeEnabled();
      expect(screen.getByLabelText('Source filter')).toBeDisabled();
      expect(screen.getByRole('button', { name: 'Source: AE' })).toBeEnabled();
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeDisabled();
      options.resolve();
      await waitFor(() =>
        expect(screen.getByLabelText('Source filter')).toBeEnabled()
      );
      expect(
        screen.getByRole('button', { name: 'Source: Aggie Enterprise' })
      ).toBeInTheDocument();
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
      expenses.resolve();
      await screen.findByRole('table');
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeEnabled();
    } finally {
      options.resolve();
      expenses.resolve();
      cleanup();
    }
  });

  it('retries options without loading an idle grid', async () => {
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    let calls = 0;
    server.use(
      http.get('/api/expensereview/filters', () =>
        ++calls === 1
          ? HttpResponse.json({ detail: 'Options failed' }, { status: 500 })
          : HttpResponse.json(filtersResponse)
      )
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review',
    });
    try {
      await screen.findByText('Options failed');
      await userEvent
        .setup()
        .click(screen.getByRole('button', { name: 'Retry filter options' }));
      await waitFor(() =>
        expect(screen.getByLabelText('Fund filter')).toBeEnabled()
      );
      expect(requests).toHaveLength(0);
      expect(calls).toBe(2);
      expect(
        screen.getByText('Select a filter or load all expenses')
      ).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('retries grid and options failures separately', async () => {
    mockExpenseReviewApi();
    let optionsCalls = 0;
    let expenseCalls = 0;
    server.use(
      http.get('/api/expensereview/filters', () =>
        ++optionsCalls === 1
          ? HttpResponse.json({ detail: 'Options failed' }, { status: 500 })
          : HttpResponse.json(filtersResponse)
      ),
      http.get('/api/expensereview/transactions', () =>
        ++expenseCalls === 1
          ? HttpResponse.json({ detail: 'Expenses failed' }, { status: 500 })
          : HttpResponse.json(transactionsResponse())
      )
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true',
    });
    try {
      await screen.findByText('Options failed');
      await screen.findByText('Expenses failed');
      const user = userEvent.setup();
      await user.click(screen.getByRole('button', { name: 'Retry expenses' }));
      await screen.findByRole('table');
      expect(optionsCalls).toBe(1);
      expect(expenseCalls).toBe(2);
      expect(screen.getByText('Options failed')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeEnabled();
      await user.click(
        screen.getByRole('button', { name: 'Retry filter options' })
      );
      await waitFor(() =>
        expect(screen.getByLabelText('Fund filter')).toBeEnabled()
      );
      expect(expenseCalls).toBe(2);
    } finally {
      cleanup();
    }
  });

  it('cancels obsolete grid requests and hides old results when the context changes', async () => {
    mockExpenseReviewApi();
    const started = completion();
    const aborted = completion();
    const response = completion();
    server.use(
      http.get('/api/expensereview/transactions', async ({ request }) => {
        if (
          new URL(request.url).searchParams.get('includeState') === 'excluded'
        ) {
          request.signal.addEventListener('abort', aborted.resolve, {
            once: true,
          });
          started.resolve();
          await response.promise;
        }
        return HttpResponse.json(transactionsResponse());
      })
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true',
    });
    try {
      await screen.findByRole('table');
      const user = userEvent.setup();
      await user.selectOptions(
        screen.getByLabelText('Include State filter'),
        'excluded'
      );
      await started.promise;
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
      expect(screen.queryByText(/grouped rows/)).not.toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeDisabled();
      await user.selectOptions(
        screen.getByLabelText('Include State filter'),
        'all'
      );
      await aborted.promise;
      await screen.findByText('Select a filter or load all expenses');
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
    } finally {
      response.resolve();
      cleanup();
    }
  });

  it('shows a successful empty result and permits an empty CSV export', async () => {
    mockExpenseReviewApi();
    server.use(
      http.get('/api/expensereview/transactions', () =>
        HttpResponse.json({
          ...transactionsResponse(),
          counts: { all: 0, excluded: 0, included: 0 },
          pageCount: 0,
          rows: [],
          totalAmount: 0,
          totalCount: 0,
        })
      )
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?loadAll=true',
    });
    try {
      await screen.findByRole('table');
      expect(screen.getByText('0 grouped rows')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeEnabled();
      expect(
        screen.queryByText('Select a filter or load all expenses')
      ).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });
});
