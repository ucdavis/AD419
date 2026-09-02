import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { render, screen, waitFor } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { server } from '@/test/mswUtils.ts';
import { OrgRListTab } from '@/components/orgrReview/OrgRListTab.tsx';
import type { OrgR } from '@/queries/orgr.ts';

function renderTab() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <OrgRListTab />
    </QueryClientProvider>
  );
}

describe('OrgRListTab', () => {
  it('lists OrgRs with mapping counts and adds a new one', async () => {
    let orgRs: OrgR[] = [
      { code: 'AARE', financialDepartmentCount: 2, nifaProjectCount: 5, referenceCount: 3 },
    ];
    const puts: string[] = [];
    server.use(
      http.get('/api/orgr/orgrs', () => HttpResponse.json(orgRs)),
      http.put('/api/orgr/orgrs/:code', ({ params }) => {
        puts.push(String(params.code));
        orgRs = [
          ...orgRs,
          { code: String(params.code), financialDepartmentCount: 0, nifaProjectCount: 0, referenceCount: 0 },
        ];
        return new HttpResponse(null, { status: 204 });
      })
    );
    const user = userEvent.setup();
    renderTab();

    expect(await screen.findByText('AARE')).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'NIFA Projects' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Financial Departments' })).toBeInTheDocument();
    expect(screen.getByRole('cell', { name: '5' })).toBeInTheDocument();
    expect(screen.getByRole('cell', { name: '2' })).toBeInTheDocument();
    expect(screen.queryByLabelText('New OrgR description')).not.toBeInTheDocument();

    await user.type(screen.getByLabelText('New OrgR code'), 'aplb');
    await user.click(screen.getByRole('button', { name: 'Add OrgR' }));

    await waitFor(() => expect(puts).toEqual(['APLB']));
    expect(await screen.findByText('APLB')).toBeInTheDocument();
  });

  it('shows the server message when a referenced OrgR cannot be deleted', async () => {
    server.use(
      http.get('/api/orgr/orgrs', () =>
        // referenceCount 0 so the Delete button is enabled; the server still
        // refuses because a mapping was added elsewhere in the meantime.
        HttpResponse.json([{ code: 'AARE', financialDepartmentCount: 0, nifaProjectCount: 0, referenceCount: 0 }])
      ),
      http.delete('/api/orgr/orgrs/AARE', () =>
        HttpResponse.text('AARE is used by 2 mappings. Reassign them before deleting it.', { status: 409 })
      )
    );
    const user = userEvent.setup();
    renderTab();

    await user.click(await screen.findByRole('button', { name: 'Delete AARE' }));
    await user.click(screen.getByRole('button', { name: 'Delete' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('AARE is used by 2 mappings');
  });
});
