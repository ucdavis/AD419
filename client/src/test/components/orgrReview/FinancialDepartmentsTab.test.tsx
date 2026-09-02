import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { render, screen, waitFor } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { server } from '@/test/mswUtils.ts';
import { FinancialDepartmentsTab } from '@/components/orgrReview/FinancialDepartmentsTab.tsx';
import type { OrgR, OrgRFinancialDepartment } from '@/queries/orgr.ts';

function renderTab() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <FinancialDepartmentsTab />
    </QueryClientProvider>
  );
}

const orgRs: OrgR[] = [
  { code: 'AARE', financialDepartmentCount: 1, nifaProjectCount: 0, referenceCount: 1 },
];

const rows: OrgRFinancialDepartment[] = [
  {
    description: 'AARE Ag and Resource Economics',
    financialDepartment: 'AARE001',
    hierarchy: [
      { code: '100000A', level: 'A', name: 'UC Davis' },
      { code: '100000B', level: 'B', name: 'UC Davis Campus' },
      { code: 'AAES00C', level: 'C', name: 'College of Agricultural and Environmental Sciences' },
      { code: 'ACL500D', level: 'D', name: 'AAES ACL5 Cluster 5 D' },
    ],
    orgR: 'AARE',
  },
  { description: 'New', financialDepartment: 'ANEW001', hierarchy: [], orgR: null },
];

function mockGets() {
  server.use(
    http.get('/api/orgr/orgrs', () => HttpResponse.json(orgRs)),
    http.get('/api/orgr/financial-departments', () => HttpResponse.json(rows))
  );
}

describe('FinancialDepartmentsTab', () => {
  it('shows unmapped rows first with the name and college-level hierarchy', async () => {
    mockGets();
    renderTab();

    const cells = await screen.findAllByRole('cell', { name: /A(ARE|NEW)001/ });
    expect(cells[0]).toHaveTextContent('ANEW001');
    expect(screen.getByText('AARE Ag and Resource Economics')).toBeInTheDocument();
    const breadcrumb = screen.getByText(
      'College of Agricultural and Environmental Sciences / AAES ACL5 Cluster 5 D'
    );
    expect(breadcrumb).toHaveAttribute('data-tip', 'AAES00C / ACL500D');
    expect(screen.queryByText(/UC Davis Campus/)).not.toBeInTheDocument();
    expect(screen.queryByRole('checkbox')).not.toBeInTheDocument();
  });

  it('patches the OrgR when the select changes', async () => {
    const patches: { code: string; orgR: string | null }[] = [];
    mockGets();
    server.use(
      http.patch('/api/orgr/financial-departments/:code', async ({ params, request }) => {
        const body = (await request.json()) as { orgR: string | null };
        patches.push({ code: String(params.code), orgR: body.orgR });
        return new HttpResponse(null, { status: 204 });
      })
    );
    const user = userEvent.setup();
    renderTab();

    const select = await screen.findByLabelText('OrgR for ANEW001');
    await user.selectOptions(select, 'AARE');

    await waitFor(() => expect(patches).toEqual([{ code: 'ANEW001', orgR: 'AARE' }]));
  });

  it('keeps the newly mapped row in place instead of resorting it away', async () => {
    const patches: { code: string; orgR: string | null }[] = [];
    mockGets();
    server.use(
      http.patch('/api/orgr/financial-departments/:code', async ({ params, request }) => {
        const body = (await request.json()) as { orgR: string | null };
        patches.push({ code: String(params.code), orgR: body.orgR });
        return new HttpResponse(null, { status: 204 });
      })
    );
    const user = userEvent.setup();
    renderTab();

    const select = await screen.findByLabelText('OrgR for ANEW001');
    await user.selectOptions(select, 'AARE');

    await waitFor(() => expect(patches).toEqual([{ code: 'ANEW001', orgR: 'AARE' }]));

    const cells = await screen.findAllByRole('cell', { name: /A(ARE|NEW)001/ });
    const codes = cells.map((cell) => cell.textContent);
    expect(codes.indexOf('ANEW001')).toBeLessThan(codes.indexOf('AARE001'));
  });

  it('shows the error and reverts the select when the patch fails', async () => {
    mockGets();
    server.use(
      http.patch('/api/orgr/financial-departments/:code', () => HttpResponse.text('nope', { status: 500 }))
    );
    const user = userEvent.setup();
    renderTab();

    const select = await screen.findByLabelText<HTMLSelectElement>('OrgR for ANEW001');
    await user.selectOptions(select, 'AARE');

    expect(await screen.findByRole('alert')).toHaveTextContent('nope');
    await waitFor(() => expect(select.value).toBe(''));
  });
});
