import { buildExpenseReviewClientTools } from '@/components/expenseReview/expenseReviewAssistantTools.ts';
import { resolveExpenseReviewView } from '@/components/expenseReview/expenseReviewSearch.ts';
import { StrictMode } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import {
  ExpenseReviewTransactionDialog,
  defaultDetailVisibility,
} from '@/components/expenseReview/ExpenseReviewTransactionDialog.tsx';
import {
  EMPTY_EXPENSE_REVIEW_FILTERS,
  expenseReviewFilterOptionsQueryOptions,
  expenseReviewTransactionsQueryOptions,
  type ExpenseReviewTransaction,
} from '@/queries/expenseReview.ts';
import { beforeAll, afterAll, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';
import {
  act,
  render,
  fireEvent,
  screen,
  waitFor,
  within,
} from '@testing-library/react';
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
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
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
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
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
        await screen.findByText('Select a filter to view expenses.')
      ).toBeInTheDocument();
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
      await chooseFilterOption(user, 'Entity', '3310 - UC Davis');
      await screen.findByRole('table');
      expect(requests.at(-1)?.searchParams.get('includeState')).toBe('all');
      expect(requests.at(-1)?.searchParams.getAll('fund')).toEqual([]);
      expect(requests.at(-1)?.searchParams.getAll('source')).toEqual([]);
      expect(requests.at(-1)?.searchParams.getAll('accountingPeriod')).toEqual(
        []
      );
      expect(requests.at(-1)?.searchParams.getAll('exclusionReason')).toEqual(
        []
      );

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

  it('replaces the grouped expense sort on Shift-click and resets to page 1', async () => {
    const user = userEvent.setup();
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    const { cleanup, router } = renderRoute({
      initialPath:
        '/workflow/expense-review?entity=%5B%223310%22%5D&page=2&sort=amount&dir=desc',
    });

    try {
      let amountHeader = await screen.findByRole('columnheader', {
        name: /Amount/,
      });
      expect(amountHeader).toHaveAttribute('aria-sort', 'descending');
      expect(screen.getByLabelText('Page')).toHaveValue(2);

      await user.keyboard('{Shift>}');
      await user.click(
        screen.getByRole('columnheader', { name: 'Financial Dept' })
      );
      await user.keyboard('{/Shift}');

      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('sortBy')).toBe(
          'financialDept'
        );
        expect(requests.at(-1)?.searchParams.get('sortDirection')).toBe('asc');
        expect(requests.at(-1)?.searchParams.get('page')).toBe('1');
      });
      expect(router.state.location.search).toEqual({
        entity: ['3310'],
        sort: 'financialDept',
      });
      expect(screen.getByLabelText('Page')).toHaveValue(1);
      expect(
        screen.getByRole('columnheader', { name: /Financial Dept/ })
      ).toHaveAttribute('aria-sort', 'ascending');
      amountHeader = screen.getByRole('columnheader', { name: 'Amount' });
      expect(amountHeader).not.toHaveAttribute('aria-sort');
      expect(amountHeader).not.toHaveTextContent(/🔼|🔽/);
      expect(
        screen
          .getAllByRole('columnheader')
          .filter((header) => header.hasAttribute('aria-sort'))
      ).toHaveLength(1);
    } finally {
      cleanup();
    }
  });

  it('requests zero-amount groups only when enabled', async () => {
    const user = userEvent.setup();
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
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
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
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
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
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
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
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
      const completionStarted = completion();
      const completionResponse = completion();
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
            completionStarted.resolve();
            await completionResponse.promise;
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
        await screen.findByText('Select a filter to view expenses.');
        await user.click(
          screen.getByRole('button', { name: /continue to orgr review/i })
        );

        await completionStarted.promise;
        const continuing = await screen.findByRole('button', {
          name: 'Continuing...',
        });
        expect(continuing).toBeDisabled();
        await user.click(continuing);
        expect(updateRequests).toBe(1);
        completionResponse.resolve();

        await waitFor(() => {
          expect(updateRequests).toBe(1);
          expect(router.state.location.pathname).toBe('/workflow/orgr-review');
        });
      } finally {
        completionResponse.resolve();
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
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
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
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D&page=2',
    });

    try {
      await screen.findByRole('table');
      await chooseFilterOption(user, 'Fund', '13U02 - Experiment Station');

      await waitFor(() => {
        expect(router.state.location.search).toEqual({
          entity: ['3310'],
          fund: ['13U02'],
        });
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
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
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
        await screen.findByText('Select a filter to view expenses.');
        expect(screen.queryByRole('table')).not.toBeInTheDocument();
        expect(screen.queryByText(/grouped rows/)).not.toBeInTheDocument();
        expect(
          within(screen.getByLabelText('Include State filter')).getByRole(
            'option',
            {
              name: 'All',
            }
          )
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
        expect(screen.queryByRole('table')).not.toBeInTheDocument();
        expect(
          screen.getByRole('button', { name: 'Export CSV' })
        ).toBeDisabled();
        expect(
          screen.queryByRole('button', { name: 'Load all expenses' })
        ).not.toBeInTheDocument();
        expect(router.state.location.search).toMatchObject({
          byPeriod: true,
          zero: true,
        });
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
        screen.queryByText('Select a filter to view expenses.')
      ).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it.each([
    'loadAll=true',
    'loadAll=false',
    'loadAll=invalid',
    'include=all',
    'source=%5B%5D',
    'byPeriod=true&zero=true&sort=amount&dir=desc&page=2&size=50',
  ])('ignores non-qualifying search %s', async (search) => {
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    const { cleanup } = renderRoute({
      initialPath: `/workflow/expense-review?${search}`,
    });
    try {
      await screen.findByText('Select a filter to view expenses.');
      expect(requests).toHaveLength(0);
    } finally {
      cleanup();
    }
  });

  it.each(['Source: Aggie Enterprise', 'Clear all'])(
    'returns to idle when filters are cleared using %s, even with cached results',
    async (buttonName) => {
      const requests: URL[] = [];
      mockExpenseReviewApi(requests);
      const { cleanup, queryClient } = renderRoute({
        initialPath: '/workflow/expense-review?source=%5B%22AE%22%5D',
      });
      try {
        await screen.findByRole('table');
        expect(
          screen.getByRole('button', { name: 'Export CSV' })
        ).toBeEnabled();
        await userEvent
          .setup()
          .click(screen.getByRole('button', { name: buttonName }));
        await screen.findByText('Select a filter to view expenses.');
        expect(screen.queryByRole('table')).not.toBeInTheDocument();
        expect(screen.queryByText(/grouped rows/)).not.toBeInTheDocument();
        expect(
          screen.getByRole('tab', { name: 'Grouped Expenses' })
        ).toBeInTheDocument();
        expect(
          screen.getByRole('button', { name: 'Export CSV' })
        ).toBeDisabled();
        expect(requests).toHaveLength(1);
        expect(
          queryClient
            .getQueriesData({ queryKey: ['expenseReview', 'transactions'] })
            .some(([, data]) => data !== undefined)
        ).toBe(true);
      } finally {
        cleanup();
      }
    }
  );

  it('applies assistant filters and clears back to idle with cached results', async () => {
    const requests: URL[] = [];
    mockExpenseReviewApi(requests);
    const { cleanup, queryClient, router } = renderRoute({
      initialPath:
        '/workflow/expense-review?byPeriod=true&dir=desc&page=3&size=50&sort=amount&zero=true',
    });
    try {
      await screen.findByText('Select a filter to view expenses.');
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
        expect(setFilters.execute({ entity: ['3310'] })).toMatchObject({
          filters: { entity: ['3310'] },
          includeState: 'all',
        });
        await navigation;
      });
      await screen.findByRole('table');
      expect(requests).toHaveLength(1);
      const params = requests[0].searchParams;
      expect(params.get('includeState')).toBe('all');
      expect(params.get('page')).toBe('1');
      expect(params.has('loadAll')).toBe(false);
      expect(params.getAll('entity')).toEqual(['3310']);
      expect(router.state.location.search).toMatchObject({
        byPeriod: true,
        dir: 'desc',
        entity: ['3310'],
        size: 50,
        sort: 'amount',
        zero: true,
      });
      expect(router.state.location.search.page).toBeUndefined();
      expect(getView.execute({})).toMatchObject({
        filters: { entity: ['3310'] },
      });
      expect(getView.execute({})).not.toHaveProperty('loadAll');
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeEnabled();

      await act(async () => {
        expect(setFilters.execute({})).toMatchObject({
          filters: resolveExpenseReviewView({}).filters,
          includeState: 'all',
        });
        await navigation;
      });
      await screen.findByText('Select a filter to view expenses.');
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeDisabled();
      expect(requests).toHaveLength(1);
      expect(getView.execute({})).toMatchObject({
        displayByPeriod: true,
        filters: resolveExpenseReviewView({}).filters,
        includeState: 'all',
        includeZeroAmounts: true,
        page: 1,
        pageSize: 50,
        sortBy: 'amount',
        sortDirection: 'desc',
      });
      expect(screen.queryByText(/grouped rows/)).not.toBeInTheDocument();
      expect(
        screen.getByRole('tab', { name: 'Grouped Expenses' })
      ).toBeInTheDocument();
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
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D&page=2',
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
      expect(router.state.location.search).not.toHaveProperty('loadAll');
      expect(router.state.location.search.page).toBeUndefined();
      await act(async () => {
        tool.execute({});
        await navigation;
      });
      await screen.findByText('Select a filter to view expenses.');
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
      expect(screen.getByText('Loading filter options...')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Source: AE' })).toBeEnabled();
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeDisabled();
      expect(
        screen.getByRole('button', { name: 'Continue to OrgR Review' })
      ).toBeDisabled();
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
      expect(
        screen.getByRole('button', { name: 'Continue to OrgR Review' })
      ).toBeEnabled();
    } finally {
      options.resolve();
      expenses.resolve();
      cleanup();
    }
  });

  it.each([false, true])(
    'keeps dropdowns and chips usable during option refresh and supports retry after failure: %s',
    async (refreshFails) => {
      mockExpenseReviewApi();
      const started = completion();
      const response = completion();
      let calls = 0;
      server.use(
        http.get('/api/expensereview/filters', async () => {
          calls += 1;
          if (calls === 2) {
            started.resolve();
            await response.promise;
            if (refreshFails) {
              return HttpResponse.json(
                { detail: 'Option refresh failed' },
                { status: 500 }
              );
            }
          }
          return HttpResponse.json(filtersResponse);
        })
      );
      const { cleanup, queryClient } = renderRoute({
        initialPath: '/workflow/expense-review?source=%5B%22AE%22%5D',
      });
      let refetch = Promise.resolve();
      try {
        await waitFor(() =>
          expect(screen.getByLabelText('Source filter')).toBeEnabled()
        );
        await act(async () => {
          refetch = queryClient.refetchQueries({
            queryKey: ['expenseReview', 'filters'],
            type: 'active',
          });
          await started.promise;
        });
        await screen.findByText('Updating filter options...');
        expect(
          screen.queryByText('Loading filter options...')
        ).not.toBeInTheDocument();
        expect(screen.getByLabelText('Fund filter')).toBeEnabled();
        expect(
          screen.getByRole('button', { name: 'Source: Aggie Enterprise' })
        ).toBeEnabled();
        const user = userEvent.setup();
        await user.click(screen.getByLabelText('Fund filter'));
        expect(
          screen.getByRole('option', { name: '13U02 - Experiment Station' })
        ).toBeInTheDocument();
        await act(async () => {
          response.resolve();
          await refetch;
        });
        if (refreshFails) {
          await screen.findByText('Option refresh failed');
          expect(screen.getByLabelText('Fund filter')).toBeEnabled();
          await user.click(
            screen.getByRole('button', { name: 'Retry filter options' })
          );
          await waitFor(() =>
            expect(
              screen.queryByText('Option refresh failed')
            ).not.toBeInTheDocument()
          );
          expect(calls).toBe(3);
        }
      } finally {
        await act(async () => {
          response.resolve();
          await refetch;
        });
        cleanup();
      }
    }
  );

  it('uses the latest filter query when selections change before an earlier response completes', async () => {
    mockExpenseReviewApi();
    const earlierStarted = completion();
    const earlierResponse = completion();
    const earlierAborted = completion();
    const latestCompleted = completion();
    server.use(
      http.get('/api/expensereview/filters', async ({ request }) => {
        const sources = new URL(request.url).searchParams.getAll('source');
        if (sources.length === 1) {
          request.signal.addEventListener('abort', earlierAborted.resolve, {
            once: true,
          });
          earlierStarted.resolve();
          await earlierResponse.promise;
          return HttpResponse.json({
            ...filtersResponse,
            funds: [{ label: 'Obsolete fund', value: 'OLD' }],
          });
        }
        if (sources.length === 2) {
          latestCompleted.resolve();
          return HttpResponse.json({
            ...filtersResponse,
            funds: [{ label: 'Latest fund', value: 'NEW' }],
          });
        }
        return HttpResponse.json(filtersResponse);
      })
    );
    const { cleanup, queryClient } = renderRoute({
      initialPath: '/workflow/expense-review',
    });
    try {
      await waitFor(() =>
        expect(screen.getByLabelText('Source filter')).toBeEnabled()
      );
      const user = userEvent.setup();
      await chooseFilterOption(user, 'Source', 'Aggie Enterprise');
      await earlierStarted.promise;
      expect(screen.getByLabelText('Source filter')).toBeEnabled();
      await chooseFilterOption(user, 'Source', 'UCPath');
      await latestCompleted.promise;
      await earlierAborted.promise;
      await waitFor(() =>
        expect(
          screen.queryByText('Updating filter options...')
        ).not.toBeInTheDocument()
      );
      await act(async () => {
        earlierResponse.resolve();
      });
      await user.click(screen.getByLabelText('Fund filter'));
      expect(
        await screen.findByRole('option', { name: 'Latest fund' })
      ).toBeInTheDocument();
      expect(
        screen.queryByRole('option', { name: 'Obsolete fund' })
      ).not.toBeInTheDocument();
      expect(
        queryClient.getQueryData(
          expenseReviewFilterOptionsQueryOptions({
            ...EMPTY_EXPENSE_REVIEW_FILTERS,
            source: ['AE', 'UCP'],
          }).queryKey
        )
      ).toMatchObject({ funds: [{ value: 'NEW' }] });
    } finally {
      earlierResponse.resolve();
      cleanup();
    }
  });

  it('reuses fresh cached filter options on mount and focus', async () => {
    mockExpenseReviewApi();
    let calls = 0;
    server.use(
      http.get('/api/expensereview/filters', () => {
        calls += 1;
        return HttpResponse.json(filtersResponse);
      })
    );
    const queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    });
    const options = expenseReviewFilterOptionsQueryOptions(
      EMPTY_EXPENSE_REVIEW_FILTERS
    );
    expect(options.staleTime).toBe(60_000);
    await queryClient.fetchQuery(options);
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review',
      queryClient,
    });
    try {
      await waitFor(() =>
        expect(screen.getByLabelText('Fund filter')).toBeEnabled()
      );
      await act(async () => {
        window.dispatchEvent(new Event('visibilitychange'));
        await queryClient.fetchQuery(options);
      });
      expect(calls).toBe(1);
      expect(
        screen.queryByText('Loading filter options...')
      ).not.toBeInTheDocument();
    } finally {
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
        screen.getByText('Select a filter to view expenses.')
      ).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('retries grid and options failures separately', async () => {
    mockExpenseReviewApi();
    let optionsCalls = 0;
    let expenseCalls = 0;
    const retryStarted = completion();
    const retryResponse = completion();
    server.use(
      http.get('/api/expensereview/filters', () =>
        ++optionsCalls === 1
          ? HttpResponse.json({ detail: 'Options failed' }, { status: 500 })
          : HttpResponse.json(filtersResponse)
      ),
      http.get('/api/expensereview/transactions', async () => {
        expenseCalls += 1;
        if (expenseCalls === 1) {
          return HttpResponse.json(
            { detail: 'Expenses failed' },
            { status: 500 }
          );
        }
        retryStarted.resolve();
        await retryResponse.promise;
        return HttpResponse.json(transactionsResponse());
      })
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
    });
    try {
      await screen.findByText('Options failed');
      await screen.findByText('Expenses failed');
      const continueButton = screen.getByRole('button', {
        name: 'Continue to OrgR Review',
      });
      expect(continueButton).toBeDisabled();
      const user = userEvent.setup();
      await user.click(screen.getByRole('button', { name: 'Retry expenses' }));
      await retryStarted.promise;
      expect(continueButton).toBeDisabled();
      retryResponse.resolve();
      await screen.findByRole('table');
      expect(continueButton).toBeEnabled();
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
      retryResponse.resolve();
      cleanup();
    }
  });

  it.each([false, true])(
    'blocks completion while refreshing visible results and after refresh failure: %s',
    async (refreshFails) => {
      mockExpenseReviewApi();
      const refreshStarted = completion();
      const refreshResponse = completion();
      let expenseCalls = 0;
      server.use(
        http.get('/api/expensereview/transactions', async () => {
          expenseCalls += 1;
          if (expenseCalls > 1) {
            refreshStarted.resolve();
            await refreshResponse.promise;
            if (refreshFails) {
              return HttpResponse.json(
                { detail: 'Refresh failed' },
                { status: 500 }
              );
            }
          }
          return HttpResponse.json(transactionsResponse());
        })
      );
      const { cleanup, queryClient } = renderRoute({
        initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
      });
      let refetch = Promise.resolve();
      try {
        await screen.findByRole('table');
        const continueButton = screen.getByRole('button', {
          name: 'Continue to OrgR Review',
        });
        expect(continueButton).toBeEnabled();

        await act(async () => {
          refetch = queryClient.refetchQueries({
            queryKey: ['expenseReview', 'transactions'],
            type: 'active',
          });
          await refreshStarted.promise;
        });
        await screen.findByText('Refreshing grouped expenses...');
        expect(continueButton).toBeDisabled();
        expect(
          within(screen.getByRole('table')).getByText('$3,600.50')
        ).toBeInTheDocument();

        await act(async () => {
          refreshResponse.resolve();
          await refetch;
        });
        if (refreshFails) {
          await screen.findByText('Refresh failed');
          expect(continueButton).toBeDisabled();
        } else {
          await waitFor(() => expect(continueButton).toBeEnabled());
        }
        expect(
          within(screen.getByRole('table')).getByText('$3,600.50')
        ).toBeInTheDocument();
        expect(expenseCalls).toBe(2);
      } finally {
        await act(async () => {
          refreshResponse.resolve();
          await refetch;
        });
        cleanup();
      }
    }
  );

  it('allows idle completion after clearing failed filters without requesting expenses again', async () => {
    mockExpenseReviewApi();
    let expenseCalls = 0;
    server.use(
      http.get('/api/expensereview/transactions', () => {
        expenseCalls += 1;
        return HttpResponse.json(
          { detail: 'Expenses failed' },
          { status: 500 }
        );
      })
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
    });
    try {
      await screen.findByText('Expenses failed');
      const continueButton = screen.getByRole('button', {
        name: 'Continue to OrgR Review',
      });
      expect(continueButton).toBeDisabled();
      await userEvent
        .setup()
        .click(screen.getByRole('button', { name: 'Clear all' }));
      await screen.findByText('Select a filter to view expenses.');
      expect(continueButton).toBeEnabled();
      expect(screen.queryByText('Expenses failed')).not.toBeInTheDocument();
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
      expect(expenseCalls).toBe(1);
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
      initialPath: '/workflow/expense-review?include=included',
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
      await screen.findByText('Select a filter to view expenses.');
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
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
    });
    try {
      await screen.findByRole('table');
      expect(screen.getByText('0 grouped rows')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeEnabled();
      expect(
        screen.getByRole('button', { name: 'Continue to OrgR Review' })
      ).toBeEnabled();
      expect(
        screen.queryByText('Select a filter to view expenses.')
      ).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });
});

function mockDetailsApi(requests: URL[] = []) {
  server.use(
    http.get(
      '/api/expensereview/groups/:groupId/transactions',
      ({ params, request }) => {
        const url = new URL(request.url);
        requests.push(url);
        const group = transactionRows.find((row) => row.id === params.groupId)!;
        const search = url.searchParams.get('search');
        const isEmpty = search === 'nothing';
        return HttpResponse.json({
          cycleEnd: '2026-09-30',
          cycleStart: '2025-10-01',
          fiscalYear: 'FY26',
          group,
          matchingAmount: isEmpty ? 0 : search ? 100 : group.amount,
          matchingCount: isEmpty ? 0 : search ? 1 : 60,
          page: Number(url.searchParams.get('page')),
          pageCount: isEmpty ? 0 : search ? 1 : 3,
          pageSize: Number(url.searchParams.get('pageSize')),
          rows: isEmpty
            ? []
            : [
                {
                  accountingPeriod: 'Oct-25',
                  accountingSequenceNumber: '9007199254740993',
                  amount: 100,
                  calculatedFte: 0.123_456,
                  documentType: 'JE',
                  employeeName: 'Ada Lovelace',
                  ernCode: 'REG',
                  ernDescription: 'Regular earnings',
                  exclusionReasons: group.exclusionReasons,
                  hours: 80,
                  id: '9007199254740995',
                  jobCode: '1234',
                  journalName: 'October journal',
                  journalReference: 'Hidden text',
                  lineDescription: 'Research expense',
                  positionNumber: '12345678',
                  salaryFringe: 'Salary',
                  transactionDate: '2025-10-15',
                },
              ],
          transactionCount: 60,
        });
      }
    )
  );
}

describe('Expense Review transaction details', () => {
  // jsdom does not implement the native dialog lifecycle.
  beforeAll(() => {
    Object.defineProperty(HTMLDialogElement.prototype, 'showModal', {
      configurable: true,
      value(this: HTMLDialogElement) {
        this.open = true;
        this.querySelector<HTMLElement>('[autofocus]')?.focus();
      },
    });
    Object.defineProperty(HTMLDialogElement.prototype, 'close', {
      configurable: true,
      value(this: HTMLDialogElement) {
        this.open = false;
        this.dispatchEvent(new Event('close'));
      },
    });
  });
  afterAll(() => {
    Reflect.deleteProperty(HTMLDialogElement.prototype, 'showModal');
    Reflect.deleteProperty(HTMLDialogElement.prototype, 'close');
  });
  it('keeps the dialog open through Strict Mode effect cleanup and native close events', async () => {
    mockDetailsApi();
    const queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    });
    const onClose = vi.fn();
    const { unmount } = render(
      <StrictMode>
        <QueryClientProvider client={queryClient}>
          <ExpenseReviewTransactionDialog
            context={{
              displayByPeriod: false,
              filters: EMPTY_EXPENSE_REVIEW_FILTERS,
              includeState: 'all',
              includeZeroAmounts: false,
            }}
            group={transactionRows[0] as ExpenseReviewTransaction}
            onClose={onClose}
            onVisibilityChange={vi.fn()}
            opener={null}
            visibility={defaultDetailVisibility('AE')}
          />
        </QueryClientProvider>
      </StrictMode>
    );
    try {
      await screen.findByText('October journal');
      const dialog = screen.getByRole('dialog');
      expect(dialog).toHaveAttribute('open');
      fireEvent(dialog, new Event('close'));
      expect(onClose).not.toHaveBeenCalled();
      fireEvent(dialog, new Event('cancel', { cancelable: true }));
      expect(onClose).toHaveBeenCalledOnce();
    } finally {
      unmount();
      queryClient.clear();
    }
  });

  it('opens by row and keyboard button, remembers source columns, and restores focus and parent state', async () => {
    const user = userEvent.setup();
    mockExpenseReviewApi();
    mockDetailsApi();
    const { cleanup, router } = renderRoute({
      initialPath:
        '/workflow/expense-review?entity=%5B%223310%22%5D&page=2&sort=amount&dir=desc',
    });
    try {
      const buttons = await screen.findAllByRole('button', {
        name: 'View transactions',
      });
      buttons[0].focus();
      await user.keyboard('{Enter}');
      let dialog = await screen.findByRole('dialog', {
        name: 'Transaction details · AE',
      });
      await within(dialog).findByText('October journal');
      const layout = vi
        .spyOn(HTMLElement.prototype, 'getClientRects')
        .mockReturnValue(
          Object.assign([new DOMRect()], { item: () => new DOMRect() })
        );
      within(dialog).getByRole('button', { name: 'Close' }).focus();
      fireEvent.keyDown(within(dialog).getByRole('button', { name: 'Close' }), {
        key: 'Tab',
        shiftKey: true,
      });
      expect(
        within(dialog).getByRole('button', { name: 'Export transactions CSV' })
      ).toHaveFocus();
      fireEvent.keyDown(
        within(dialog).getByRole('button', { name: 'Export transactions CSV' }),
        { key: 'Tab' }
      );
      expect(
        within(dialog).getByRole('button', { name: 'Close' })
      ).toHaveFocus();
      layout.mockRestore();
      expect(
        within(dialog).getByRole('columnheader', {
          name: 'Accounting sequence number',
        })
      ).toBeInTheDocument();
      expect(
        within(dialog).queryByRole('columnheader', { name: 'Employee name' })
      ).not.toBeInTheDocument();
      expect(
        within(dialog).queryByRole('columnheader', { name: 'Document type' })
      ).not.toBeInTheDocument();
      await user.click(
        within(dialog).getByText('Columns', { selector: 'summary' })
      );
      await user.click(within(dialog).getByLabelText('Document type'));
      expect(
        within(dialog).getByRole('columnheader', { name: 'Document type' })
      ).toBeInTheDocument();
      await user.click(within(dialog).getByRole('button', { name: 'Close' }));
      expect(buttons[0]).toHaveFocus();
      expect(router.state.location.search).toEqual({
        dir: 'desc',
        entity: ['3310'],
        page: 2,
        sort: 'amount',
      });
      await user.click(buttons[1].closest('tr')!.querySelector('td')!);
      dialog = await screen.findByRole('dialog', {
        name: 'Transaction details · UCP',
      });
      await within(dialog).findByText('Ada Lovelace');
      expect(
        within(dialog).getByRole('columnheader', { name: 'Employee name' })
      ).toBeInTheDocument();
      expect(
        within(dialog).queryByRole('columnheader', { name: 'Job code' })
      ).not.toBeInTheDocument();
      expect(within(dialog).getByTitle('Regular earnings')).toHaveTextContent(
        'REG'
      );
      await user.click(within(dialog).getByRole('button', { name: 'Close' }));
      await user.click(buttons[0]);
      dialog = await screen.findByRole('dialog');
      await within(dialog).findByRole('columnheader', {
        name: 'Document type',
      });
      await user.click(
        within(dialog).getByText('Columns', { selector: 'summary' })
      );
      await user.click(
        within(dialog).getByRole('button', { name: 'Reset columns' })
      );
      expect(
        within(dialog).queryByRole('columnheader', { name: 'Document type' })
      ).not.toBeInTheDocument();
      dialog.dispatchEvent(new Event('cancel', { cancelable: true }));
      await waitFor(() =>
        expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
      );
      expect(buttons[0]).toHaveFocus();
    } finally {
      cleanup();
    }
  });

  it('searches on submit, resets pages for search/sort/size, exports current search, and closes on parent context changes', async () => {
    const user = userEvent.setup();
    const requests: URL[] = [];
    const exports: URL[] = [];
    mockExpenseReviewApi();
    mockDetailsApi(requests);
    server.use(
      http.get(
        '/api/expensereview/groups/:groupId/transactions.csv',
        ({ request }) => {
          exports.push(new URL(request.url));
          return new HttpResponse('Export failed', { status: 500 });
        }
      )
    );
    const { cleanup, router } = renderRoute({
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
    });
    try {
      await user.click(
        (await screen.findAllByRole('button', { name: 'View transactions' }))[1]
      );
      const dialog = await screen.findByRole('dialog');
      await within(dialog).findByText('Ada Lovelace');
      expect(requests.at(-1)!.searchParams.get('pageSize')).toBe('25');
      expect(requests.at(-1)!.searchParams.getAll('entity')).toEqual(['3310']);
      await user.click(within(dialog).getByRole('button', { name: 'Next' }));
      await waitFor(() =>
        expect(requests.at(-1)!.searchParams.get('page')).toBe('2')
      );
      await within(dialog).findByText('Ada Lovelace');
      const input = within(dialog).getByLabelText('Search transactions');
      await user.type(input, 'hidden');
      expect(requests.at(-1)!.searchParams.get('search')).toBeNull();
      await user.keyboard('{Enter}');
      await within(dialog).findByText('Matching: 1 transactions · $100.00');
      expect(
        within(dialog).getByText('Full group: 60 transactions · $2,400.00')
      ).toBeInTheDocument();
      expect(requests.at(-1)!.searchParams.get('page')).toBe('1');
      await user.click(
        within(dialog).getByRole('button', { name: 'Export transactions CSV' })
      );
      await within(dialog).findByText(/CSV export could not be downloaded/);
      expect(exports[0].searchParams.get('search')).toBe('hidden');
      expect(exports[0].searchParams.getAll('entity')).toEqual(['3310']);
      expect(exports[0].searchParams.has('page')).toBe(false);
      expect(exports[0].searchParams.has('columns')).toBe(false);
      await user.click(within(dialog).getByRole('button', { name: 'Clear' }));
      await within(dialog).findByText('Ada Lovelace');
      expect(input).toHaveValue('');
      await user.click(within(dialog).getByRole('button', { name: 'Next' }));
      await within(dialog).findByText('Ada Lovelace');
      await user.click(
        within(dialog).getByRole('columnheader', { name: 'Employee name' })
      );
      await waitFor(() => {
        expect(requests.at(-1)!.searchParams.get('detailSortBy')).toBe(
          'employeeName'
        );
        expect(requests.at(-1)!.searchParams.get('page')).toBe('1');
      });
      await within(dialog).findByText('Ada Lovelace');
      await user.click(within(dialog).getByRole('button', { name: 'Next' }));
      await within(dialog).findByText('Ada Lovelace');
      await user.selectOptions(
        within(dialog).getByLabelText('Rows per page'),
        '50'
      );
      await waitFor(() => {
        expect(requests.at(-1)!.searchParams.get('pageSize')).toBe('50');
        expect(requests.at(-1)!.searchParams.get('page')).toBe('1');
      });
      await within(dialog).findByText('Ada Lovelace');
      await user.type(input, 'nothing');
      await user.click(within(dialog).getByRole('button', { name: 'Search' }));
      await within(dialog).findByText('No transactions match this search.');
      await router.navigate({
        search: { byPeriod: true, entity: ['3310'] },
        to: '/workflow/expense-review',
      });
      await waitFor(() =>
        expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
      );
    } finally {
      cleanup();
    }
  });

  it('closes and cancels pending details when parent filters are cleared', async () => {
    const user = userEvent.setup();
    const groupedRequests: URL[] = [];
    const detailsRequested = completion();
    let complete: ((response: Response) => void) | undefined;
    let detailSignal: AbortSignal | undefined;
    mockExpenseReviewApi(groupedRequests);
    server.use(
      http.get(
        '/api/expensereview/groups/:groupId/transactions',
        ({ request }) => {
          detailSignal = request.signal;
          return new Promise<Response>((resolve) => {
            complete = resolve;
            detailsRequested.resolve();
          });
        }
      )
    );
    const { cleanup, router } = renderRoute({
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
    });

    try {
      await user.click(
        (await screen.findAllByRole('button', { name: 'View transactions' }))[0]
      );
      await detailsRequested.promise;
      expect(await screen.findByRole('dialog')).toBeInTheDocument();
      expect(detailSignal?.aborted).toBe(false);

      await act(async () => {
        await router.navigate({ search: {}, to: '/workflow/expense-review' });
      });

      expect(
        await screen.findByText('Select a filter to view expenses.')
      ).toBeInTheDocument();
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
      expect(detailSignal?.aborted).toBe(true);
      expect(groupedRequests).toHaveLength(1);
      expect(groupedRequests[0].searchParams.getAll('entity')).toEqual([
        '3310',
      ]);
      expect(screen.getByRole('button', { name: 'Export CSV' })).toBeDisabled();
    } finally {
      complete?.(HttpResponse.json({}));
      cleanup();
    }
  });

  it('replaces the detail sort on Shift-click, resets to page 1, and exports the selected sort', async () => {
    const user = userEvent.setup();
    const requests: URL[] = [];
    const exports: URL[] = [];
    mockExpenseReviewApi();
    mockDetailsApi(requests);
    server.use(
      http.get(
        '/api/expensereview/groups/:groupId/transactions.csv',
        ({ request }) => {
          exports.push(new URL(request.url));
          return new HttpResponse('Export failed', { status: 500 });
        }
      )
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
    });

    try {
      await user.click(
        (await screen.findAllByRole('button', { name: 'View transactions' }))[1]
      );
      const dialog = await screen.findByRole('dialog');
      await within(dialog).findByText('Ada Lovelace');
      let dateHeader = within(dialog).getByRole('columnheader', {
        name: /Pay-period end date/,
      });
      expect(dateHeader).toHaveAttribute('aria-sort', 'ascending');
      await user.click(within(dialog).getByRole('button', { name: 'Next' }));
      await waitFor(() =>
        expect(requests.at(-1)?.searchParams.get('page')).toBe('2')
      );
      await within(dialog).findByText('Ada Lovelace');
      expect(within(dialog).getByLabelText('Page')).toHaveValue(2);

      await user.keyboard('{Shift>}');
      await user.click(
        within(dialog).getByRole('columnheader', { name: 'Employee name' })
      );
      await user.keyboard('{/Shift}');

      await waitFor(() => {
        expect(requests.at(-1)?.searchParams.get('detailSortBy')).toBe(
          'employeeName'
        );
        expect(requests.at(-1)?.searchParams.get('detailSortDirection')).toBe(
          'asc'
        );
        expect(requests.at(-1)?.searchParams.get('page')).toBe('1');
      });
      await within(dialog).findByText('Ada Lovelace');
      expect(within(dialog).getByLabelText('Page')).toHaveValue(1);
      expect(
        within(dialog).getByRole('columnheader', { name: /Employee name/ })
      ).toHaveAttribute('aria-sort', 'ascending');
      dateHeader = within(dialog).getByRole('columnheader', {
        name: 'Pay-period end date',
      });
      expect(dateHeader).not.toHaveAttribute('aria-sort');
      expect(dateHeader).not.toHaveTextContent(/🔼|🔽/);
      expect(
        within(dialog)
          .getAllByRole('columnheader')
          .filter((header) => header.hasAttribute('aria-sort'))
      ).toHaveLength(1);

      await user.click(
        within(dialog).getByRole('button', { name: 'Export transactions CSV' })
      );
      await within(dialog).findByText(/CSV export could not be downloaded/);
      expect(exports).toHaveLength(1);
      expect(exports[0].searchParams.get('detailSortBy')).toBe('employeeName');
      expect(exports[0].searchParams.get('detailSortDirection')).toBe('asc');
    } finally {
      cleanup();
    }
  });

  it('shows loading and an error with retry, and cancels obsolete requests when closed', async () => {
    const user = userEvent.setup();
    mockExpenseReviewApi();
    let complete!: (response: Response) => void;
    let signal: AbortSignal | undefined;
    server.use(
      http.get(
        '/api/expensereview/groups/:groupId/transactions',
        ({ request }) => {
          signal = request.signal;
          return new Promise<Response>((resolve) => {
            complete = resolve;
          });
        }
      )
    );
    const { cleanup } = renderRoute({
      initialPath: '/workflow/expense-review?entity=%5B%223310%22%5D',
    });
    try {
      await user.click(
        (await screen.findAllByRole('button', { name: 'View transactions' }))[0]
      );
      const dialog = await screen.findByRole('dialog');
      await within(dialog).findByText('Loading transactions…');
      await waitFor(() => expect(complete).toBeDefined());
      complete(new HttpResponse('Unavailable', { status: 500 }));
      await within(dialog).findByRole('alert');
      mockDetailsApi();
      await user.click(within(dialog).getByRole('button', { name: 'Retry' }));
      await within(dialog).findByText('October journal');
      await user.click(within(dialog).getByRole('button', { name: 'Close' }));
      server.use(
        http.get(
          '/api/expensereview/groups/:groupId/transactions',
          ({ request }) => {
            signal = request.signal;
            return new Promise<Response>((resolve) => {
              complete = resolve;
            });
          }
        )
      );
      await user.click(
        screen.getAllByRole('button', { name: 'View transactions' })[1]
      );
      await screen.findByText('Loading transactions…');
      await user.click(
        within(screen.getByRole('dialog')).getByRole('button', {
          name: 'Close',
        })
      );
      await waitFor(() => expect(signal?.aborted).toBe(true));
      complete(HttpResponse.json({}));
    } finally {
      cleanup();
    }
  });
});
