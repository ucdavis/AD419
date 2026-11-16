import { FteOverOneTab } from '@/components/autoAssociations/FteOverOneTab.tsx';
import type {
  ExpenseReviewEmployeeTransactionsResponse,
  ExpenseReviewTransactionDetail,
} from '@/queries/expenseReview.ts';
import { server } from '@/test/mswUtils.ts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import {
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

const transaction: ExpenseReviewTransactionDetail = {
  accountingPeriod: 'Oct-24',
  accountingSequenceNumber: null,
  amount: 100,
  calculatedFte: 0.25,
  documentType: null,
  employeeId: 'E1',
  employeeName: 'PI One',
  ernCode: 'REG',
  ernDescription: 'Regular earnings',
  exclusionReasons: [],
  financialDepartment: 'D1',
  fund: 'F201',
  hours: 80,
  id: 'SCT123_1_1_E1_0_REG_RUN',
  jobCode: '1234',
  journalName: null,
  journalReference: null,
  lineDescription: null,
  positionNumber: '12345678',
  project: 'PROJECT-1',
  reportFteContribution: 0.25,
  reportIncluded: true,
  reportStatus: 'Report row',
  salaryFringe: 'Salary',
  transactionDate: '2024-10-15T00:00:00',
  transactionId: 'SCT123',
  ucEarnEndDate: '2024-09-30T00:00:00',
};

function response(url: URL): ExpenseReviewEmployeeTransactionsResponse {
  const scope = url.searchParams.get('scope') === 'all' ? 'all' : 'report';
  const empty = url.searchParams.get('search') === 'nothing';
  return {
    cycleEnd: '2025-09-30',
    cycleStart: '2024-10-01',
    employeeId: 'E1',
    employeeName: 'PI One',
    fiscalYear: 'FY25',
    matchingAmount: empty ? 0 : 100,
    matchingCount: empty ? 0 : 60,
    page: Number(url.searchParams.get('page') ?? 1),
    pageCount: empty ? 0 : 3,
    pageSize: Number(url.searchParams.get('pageSize') ?? 25),
    reportFte: 1.3,
    rows: empty
      ? []
      : [
          {
            ...transaction,
            transactionId: scope === 'all' ? 'PJ456' : 'SCT123',
          },
        ],
    scope,
    totalAmount: scope === 'all' ? 300 : 200,
    transactionCount: scope === 'all' ? 70 : 60,
  };
}

function mockList() {
  server.use(
    http.get('/api/autoassociations/fte-over-one', () =>
      HttpResponse.json({
        cycleEnd: '2025-09-30',
        cycleStart: '2024-10-01',
        data: [
          { employeeId: 'E1', employeeName: 'PI One', fte: 1.3, rowCount: 3 },
        ],
        fiscalYear: 'FY25',
      })
    )
  );
}

function renderTab() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false, staleTime: Infinity } },
  });
  const tree = (buildId: number) => (
    <QueryClientProvider client={queryClient}>
      <FteOverOneTab buildId={buildId} />
    </QueryClientProvider>
  );
  const result = render(tree(1));
  return { ...result, rebuild: () => result.rerender(tree(2)) };
}

function completion() {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

describe('FTE employee transactions', () => {
  beforeAll(() => {
    Object.defineProperty(HTMLDialogElement.prototype, 'showModal', {
      configurable: true,
      value(this: HTMLDialogElement) {
        this.open = true;
      },
    });
    Object.defineProperty(HTMLDialogElement.prototype, 'close', {
      configurable: true,
      value(this: HTMLDialogElement) {
        this.open = false;
      },
    });
  });
  afterAll(() => {
    Reflect.deleteProperty(HTMLDialogElement.prototype, 'showModal');
    Reflect.deleteProperty(HTMLDialogElement.prototype, 'close');
  });

  it('opens report rows by keyboard, shows payroll fields and restores the report and focus', async () => {
    mockList();
    const requests: URL[] = [];
    server.use(
      http.get(
        '/api/expensereview/employees/:employeeId/transactions',
        ({ request }) => {
          const url = new URL(request.url);
          requests.push(url);
          return HttpResponse.json(response(url));
        }
      )
    );
    const user = userEvent.setup();
    renderTab();
    await screen.findByRole('heading', { name: 'Employees over 1.1 FTE' });
    await user.type(
      screen.getByPlaceholderText('Search all columns...'),
      'PI One'
    );
    const opener = screen.getByRole('button', {
      name: 'View transactions for PI One',
    });
    opener.focus();
    await user.keyboard('{Enter}');
    const dialog = await screen.findByRole('dialog', {
      name: 'Transaction details · UCP',
    });
    await within(dialog).findByText('SCT123');
    expect(requests[0].searchParams.get('scope')).toBe('report');
    expect(
      within(dialog).getByRole('radio', { name: 'Report rows only' })
    ).toBeChecked();
    expect(
      within(dialog).getByText('Report FTE: 1.300000')
    ).toBeInTheDocument();
    for (const name of [
      'Employee ID',
      'Pay End Date',
      'UC Earn End Date',
      'Transaction ID',
      'Salary/fringe',
      'Calculated FTE',
      'Report FTE contribution',
      'Financial Dept',
      'Fund',
      'Project',
    ]) {
      expect(
        within(dialog).getByRole('columnheader', { name: new RegExp(name) })
      ).toBeInTheDocument();
    }
    expect(within(dialog).getByText('2024-09-30')).toBeInTheDocument();
    expect(within(dialog).getByText('2024-10-15')).toBeInTheDocument();
    expect(
      within(dialog).queryByRole('columnheader', { name: 'Entity' })
    ).not.toBeInTheDocument();
    await user.click(
      within(dialog).getByText('Columns', { selector: 'summary' })
    );
    await user.click(within(dialog).getByLabelText('Entity'));
    expect(
      within(dialog).getByRole('columnheader', { name: 'Entity' })
    ).toBeInTheDocument();
    await user.click(
      within(dialog).getByRole('button', { name: 'Reset columns' })
    );
    expect(
      within(dialog).queryByRole('columnheader', { name: 'Entity' })
    ).not.toBeInTheDocument();
    fireEvent(dialog, new Event('cancel', { cancelable: true }));
    await waitFor(() =>
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    );
    expect(opener).toHaveFocus();
    expect(screen.getByPlaceholderText('Search all columns...')).toHaveValue(
      'PI One'
    );
  });

  it('switches scopes without stale rows or totals and exports the selected search and sort', async () => {
    mockList();
    const requestedAll = completion();
    const releaseAll = completion();
    const requests: URL[] = [];
    const exports: URL[] = [];
    server.use(
      http.get(
        '/api/expensereview/employees/:employeeId/transactions',
        async ({ request }) => {
          const url = new URL(request.url);
          requests.push(url);
          if (url.searchParams.get('scope') === 'all') {
            requestedAll.resolve();
            await releaseAll.promise;
          }
          return HttpResponse.json(response(url));
        }
      ),
      http.get(
        '/api/expensereview/employees/:employeeId/transactions.csv',
        ({ request }) => {
          exports.push(new URL(request.url));
          return new HttpResponse('Export failed', { status: 500 });
        }
      )
    );
    const user = userEvent.setup();
    renderTab();
    await user.click(
      await screen.findByRole('button', {
        name: 'View transactions for PI One',
      })
    );
    const dialog = await screen.findByRole('dialog');
    try {
      await within(dialog).findByText('SCT123');
      await user.click(within(dialog).getByRole('button', { name: 'Next' }));
      await waitFor(() =>
        expect(requests.at(-1)?.searchParams.get('page')).toBe('2')
      );
      await within(dialog).findByText('SCT123');
      await user.click(
        within(dialog).getByRole('radio', { name: 'All in-cycle rows' })
      );
      await requestedAll.promise;
      expect(requests.at(-1)?.searchParams.get('page')).toBe('1');
      expect(within(dialog).queryByText('SCT123')).not.toBeInTheDocument();
      expect(
        within(dialog).queryByText(/60 transactions/)
      ).not.toBeInTheDocument();
      expect(
        within(dialog).getByText('Report FTE: 1.300000')
      ).toBeInTheDocument();
      expect(
        within(dialog).getByRole('button', { name: 'Export transactions CSV' })
      ).toBeDisabled();
      releaseAll.resolve();
      await within(dialog).findByText('PJ456');
      expect(
        within(dialog).getByText('All in-cycle rows: 70 transactions · $300.00')
      ).toBeInTheDocument();
      await user.type(
        within(dialog).getByRole('textbox', { name: 'Search transactions' }),
        'PJ456'
      );
      await user.click(within(dialog).getByRole('button', { name: 'Search' }));
      await waitFor(() =>
        expect(requests.at(-1)?.searchParams.get('search')).toBe('PJ456')
      );
      await within(dialog).findByText('PJ456');
      await user.click(
        within(dialog).getByRole('columnheader', { name: 'UC Earn End Date' })
      );
      await waitFor(() =>
        expect(requests.at(-1)?.searchParams.get('detailSortBy')).toBe(
          'ucEarnEndDate'
        )
      );
      await within(dialog).findByText('PJ456');
      await user.click(
        within(dialog).getByRole('button', { name: 'Export transactions CSV' })
      );
      await within(dialog).findByRole('alert');
      expect(exports[0].searchParams.get('scope')).toBe('all');
      expect(exports[0].searchParams.get('search')).toBe('PJ456');
      expect(exports[0].searchParams.get('detailSortBy')).toBe('ucEarnEndDate');
      expect(exports[0].searchParams.has('page')).toBe(false);
      expect(
        within(dialog).getByText('Report FTE: 1.300000')
      ).toBeInTheDocument();
    } finally {
      releaseAll.resolve();
    }
  });

  it('retries a failed detail request and shows an empty search without losing report FTE', async () => {
    mockList();
    let failed = false;
    server.use(
      http.get(
        '/api/expensereview/employees/:employeeId/transactions',
        ({ request }) => {
          if (!failed) {
            failed = true;
            return new HttpResponse('No current build', { status: 409 });
          }
          return HttpResponse.json(response(new URL(request.url)));
        }
      )
    );
    const user = userEvent.setup();
    renderTab();
    await user.click(
      await screen.findByRole('button', {
        name: 'View transactions for PI One',
      })
    );
    const dialog = await screen.findByRole('dialog');
    expect(await within(dialog).findByRole('alert')).toHaveTextContent(
      'Unable to load transactions.'
    );
    await user.click(within(dialog).getByRole('button', { name: 'Retry' }));
    await within(dialog).findByText('SCT123');
    await user.type(
      within(dialog).getByRole('textbox', { name: 'Search transactions' }),
      'nothing'
    );
    await user.click(within(dialog).getByRole('button', { name: 'Search' }));
    await within(dialog).findByText('No transactions match this search.');
    expect(
      within(dialog).getByText('Report FTE: 1.300000')
    ).toBeInTheDocument();
    expect(
      within(dialog).getByText('Matching: 0 transactions · $0.00')
    ).toBeInTheDocument();
    expect(
      within(dialog).getByRole('button', { name: 'Export transactions CSV' })
    ).toBeEnabled();
  });

  it('loads fresh details for a rebuilt report instead of reusing the previous build cache', async () => {
    mockList();
    const started = completion();
    const release = completion();
    let calls = 0;
    server.use(
      http.get(
        '/api/expensereview/employees/:employeeId/transactions',
        async ({ request }) => {
          calls++;
          if (calls > 1) {
            started.resolve();
            await release.promise;
          }
          return HttpResponse.json(response(new URL(request.url)));
        }
      )
    );
    const user = userEvent.setup();
    const { rebuild } = renderTab();
    await user.click(
      await screen.findByRole('button', {
        name: 'View transactions for PI One',
      })
    );
    await within(await screen.findByRole('dialog')).findByText('SCT123');
    try {
      rebuild();
      await started.promise;
      expect(
        within(screen.getByRole('dialog')).queryByText('SCT123')
      ).not.toBeInTheDocument();
      release.resolve();
      await within(screen.getByRole('dialog')).findByText('SCT123');
      expect(calls).toBe(2);
    } finally {
      release.resolve();
    }
  });
});
