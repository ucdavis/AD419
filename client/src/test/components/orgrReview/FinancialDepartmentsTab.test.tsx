import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { render, screen, waitFor } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { server } from '@/test/mswUtils.ts';
import { FinancialDepartmentsTab } from '@/components/orgrReview/FinancialDepartmentsTab.tsx';
import type { OrgRFinancialDepartment } from '@/queries/orgr.ts';

function renderTab() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <FinancialDepartmentsTab />
    </QueryClientProvider>
  );
}

const rows: OrgRFinancialDepartment[] = [
  { description: 'ARE', financialDepartment: 'AARE001', hierarchy: [{ code: 'AAES00C', level: 'C', name: 'CAES' }], inCycle: true, orgR: 'AARE' },
  { description: 'New', financialDepartment: 'ANEW001', hierarchy: [], inCycle: true, orgR: null },
  { description: 'Old', financialDepartment: '9OLD001', hierarchy: [], inCycle: false, orgR: 'AARE' },
  { description: 'Unmapped Old', financialDepartment: '8OLD002', hierarchy: [], inCycle: false, orgR: null },
];

describe('FinancialDepartmentsTab', () => {
  it('shows in-cycle rows by default with unmapped first, and toggles to all', async () => {
    server.use(
      http.get('/api/orgr/orgrs', () => HttpResponse.json([{ code: 'AARE', referenceCount: 2 }])),
      http.get('/api/orgr/financial-departments', () => HttpResponse.json(rows))
    );
    const user = userEvent.setup();
    renderTab();

    const cells = await screen.findAllByRole('cell', { name: /A(ARE|NEW)001/ });
    expect(cells[0]).toHaveTextContent('ANEW001');
    expect(screen.queryByText('9OLD001')).not.toBeInTheDocument();
    // Unmapped rows are shown even when out of cycle and the toggle is on.
    expect(await screen.findByText('8OLD002')).toBeInTheDocument();

    await user.click(screen.getByLabelText('Only departments in this cycle (unmapped always shown)'));
    expect(await screen.findByText('9OLD001')).toBeInTheDocument();
  });

  it('patches the OrgR when the select changes', async () => {
    const patches: { code: string; orgR: string | null }[] = [];
    server.use(
      http.get('/api/orgr/orgrs', () => HttpResponse.json([{ code: 'AARE', referenceCount: 2 }])),
      http.get('/api/orgr/financial-departments', () => HttpResponse.json(rows)),
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
    server.use(
      http.get('/api/orgr/orgrs', () => HttpResponse.json([{ code: 'AARE', referenceCount: 2 }])),
      http.get('/api/orgr/financial-departments', () => HttpResponse.json(rows)),
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
    server.use(
      http.get('/api/orgr/orgrs', () => HttpResponse.json([{ code: 'AARE', referenceCount: 2 }])),
      http.get('/api/orgr/financial-departments', () => HttpResponse.json(rows)),
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
