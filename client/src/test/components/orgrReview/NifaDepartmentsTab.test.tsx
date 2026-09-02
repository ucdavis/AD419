import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { render, screen, waitFor } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { server } from '@/test/mswUtils.ts';
import { NifaDepartmentsTab } from '@/components/orgrReview/NifaDepartmentsTab.tsx';

function renderTab() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <NifaDepartmentsTab />
    </QueryClientProvider>
  );
}

describe('NifaDepartmentsTab', () => {
  it('lists departments with project counts and patches on change', async () => {
    const patches: { code: string; orgR: string | null }[] = [];
    server.use(
      http.get('/api/orgr/orgrs', () => HttpResponse.json([{ code: 'AARE', financialDepartmentCount: 0, nifaProjectCount: 0, referenceCount: 0 }])),
      http.get('/api/orgr/nifa-departments', () =>
        HttpResponse.json([
          { nifaDepartment: 'ARE', orgR: 'AARE', projectCount: 2 },
          { nifaDepartment: 'ESP', orgR: null, projectCount: 1 },
        ])
      ),
      http.patch('/api/orgr/nifa-departments/:code', async ({ params, request }) => {
        const body = (await request.json()) as { orgR: string | null };
        patches.push({ code: String(params.code), orgR: body.orgR });
        return new HttpResponse(null, { status: 204 });
      })
    );
    const user = userEvent.setup();
    renderTab();

    expect(await screen.findByText('ESP')).toBeInTheDocument();
    expect(screen.getByRole('cell', { name: '2' })).toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText('OrgR for ESP'), 'AARE');

    await waitFor(() => expect(patches).toEqual([{ code: 'ESP', orgR: 'AARE' }]));
  });
});
