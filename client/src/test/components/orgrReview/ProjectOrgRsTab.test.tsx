import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { render, screen, waitFor } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { server } from '@/test/mswUtils.ts';
import { ProjectOrgRsTab } from '@/components/orgrReview/ProjectOrgRsTab.tsx';
import type { ProjectOrgR } from '@/queries/orgr.ts';

function renderTab() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <ProjectOrgRsTab />
    </QueryClientProvider>
  );
}

const rows: ProjectOrgR[] = [
  { accessionNumber: '1000001', nifaProjectNumber: 'CA-D-ARE-2868-H', orgR: 'AARE', projectDirector: 'Doe', source: 'Default', title: 'Water' },
  { accessionNumber: '1000001', nifaProjectNumber: 'CA-D-ARE-2868-H', orgR: 'APLS', projectDirector: 'Doe', source: 'Manual', title: 'Water' },
];

describe('ProjectOrgRsTab', () => {
  it('marks manual rows removable and posts additions', async () => {
    const posts: unknown[] = [];
    const deletes: string[] = [];
    server.use(
      http.get('/api/orgr/orgrs', () =>
        HttpResponse.json([
          { code: 'AARE', financialDepartmentCount: 0, nifaProjectCount: 0, referenceCount: 1 },
          { code: 'APLS', financialDepartmentCount: 0, nifaProjectCount: 0, referenceCount: 1 },
        ])
      ),
      http.get('/api/orgr/projects', () => HttpResponse.json(rows)),
      http.post('/api/orgr/projects', async ({ request }) => {
        posts.push(await request.json());
        return new HttpResponse(null, { status: 204 });
      }),
      http.delete('/api/orgr/projects/:accession/:orgR', ({ params }) => {
        deletes.push(`${params.accession}/${params.orgR}`);
        return new HttpResponse(null, { status: 204 });
      })
    );
    const user = userEvent.setup();
    renderTab();

    expect(await screen.findAllByText('1000001')).toHaveLength(2);
    expect(screen.getAllByRole('button', { name: /Remove/ })).toHaveLength(1);

    await user.type(screen.getByLabelText('Accession number'), '1000001');
    await user.selectOptions(screen.getByLabelText('OrgR to add'), 'AARE');
    await user.click(screen.getByRole('button', { name: 'Add to OrgR' }));
    await waitFor(() =>
      expect(posts).toEqual([{ accessionNumber: '1000001', orgR: 'AARE' }])
    );

    await user.click(screen.getByRole('button', { name: 'Remove 1000001 from APLS' }));
    await waitFor(() => expect(deletes).toEqual(['1000001/APLS']));
  });
});
