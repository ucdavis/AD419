import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { render, screen, waitFor, within } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { server } from '@/test/mswUtils.ts';
import { PiAppointmentsTab } from '@/components/orgrReview/PiAppointmentsTab.tsx';
import type { Pi, PiAppointment } from '@/queries/orgr.ts';

function renderTab() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <PiAppointmentsTab />
    </QueryClientProvider>
  );
}

const pis: Pi[] = [
  {
    homeOrgRs: ['AARE'],
    name: 'Doe, Jane',
    projectCount: 1,
    skipped204Count: 3,
    ucpEmployeeId: '10000002',
  },
  {
    homeOrgRs: ['ANUT'],
    name: 'Slupsky, Carolyn',
    projectCount: 2,
    skipped204Count: 1,
    ucpEmployeeId: '10000001',
  },
];

const appointments: PiAppointment[] = [
  {
    homeOrgRs: ['ANUT'],
    name: 'Slupsky, Carolyn',
    orgR: 'AFST',
    projectCount: 2,
    skipped204Count: 1,
    ucpEmployeeId: '10000001',
  },
];

function mockApi() {
  const posts: unknown[] = [];
  const deletes: string[] = [];
  server.use(
    http.get('/api/orgr/orgrs', () =>
      HttpResponse.json([
        { code: 'AFST', financialDepartmentCount: 0, nifaProjectCount: 0, referenceCount: 1 },
        { code: 'ANUT', financialDepartmentCount: 0, nifaProjectCount: 0, referenceCount: 1 },
      ])
    ),
    http.get('/api/orgr/pis', () => HttpResponse.json(pis)),
    http.get('/api/orgr/pi-appointments', () => HttpResponse.json(appointments)),
    http.post('/api/orgr/pi-appointments', async ({ request }) => {
      posts.push(await request.json());
      return new HttpResponse(null, { status: 204 });
    }),
    http.delete('/api/orgr/pi-appointments/:employeeId/:orgR', ({ params }) => {
      deletes.push(`${params.employeeId}/${params.orgR}`);
      return new HttpResponse(null, { status: 204 });
    })
  );
  return { deletes, posts };
}

describe('PiAppointmentsTab', () => {
  it('finds a PI by typing and adds an appointment for the chosen PI and OrgR', async () => {
    const { posts } = mockApi();
    const user = userEvent.setup();
    renderTab();

    const piInput = await screen.findByRole('combobox', { name: 'PI' });
    const add = screen.getByRole('button', { name: 'Add appointment' });
    expect(add).toBeDisabled();

    await user.type(piInput, 'doe');
    expect(
      screen.queryByRole('option', { name: 'Slupsky, Carolyn (2 projects)' })
    ).not.toBeInTheDocument();
    await user.click(screen.getByRole('option', { name: 'Doe, Jane (1 project)' }));
    expect(piInput).toHaveValue('Doe, Jane (1 project)');

    await user.selectOptions(screen.getByLabelText('OrgR to add'), 'AFST');
    await user.click(add);

    await waitFor(() =>
      expect(posts).toEqual([{ orgR: 'AFST', ucpEmployeeId: '10000002' }])
    );
    await waitFor(() =>
      expect(screen.getByRole('combobox', { name: 'PI' })).toHaveValue('')
    );
  });

  it('drops the chosen PI when the search text is edited', async () => {
    mockApi();
    const user = userEvent.setup();
    renderTab();

    const piInput = await screen.findByRole('combobox', { name: 'PI' });
    await user.type(piInput, 'slup');
    await user.click(screen.getByRole('option', { name: 'Slupsky, Carolyn (2 projects)' }));
    await user.selectOptions(screen.getByLabelText('OrgR to add'), 'AFST');
    const add = screen.getByRole('button', { name: 'Add appointment' });
    expect(add).toBeEnabled();

    await user.type(piInput, '{Backspace}');
    expect(add).toBeDisabled();
  });

  it('lists appointments with their default and additional OrgR and removes one', async () => {
    const { deletes } = mockApi();
    const user = userEvent.setup();
    renderTab();

    const section = await screen.findByRole('region', { name: 'PI appointments' });
    const row = within(section).getByRole('row', { name: /Slupsky, Carolyn/ });
    expect(within(row).getByText('ANUT')).toBeInTheDocument();
    expect(within(row).getByText('AFST')).toBeInTheDocument();

    await user.click(
      within(row).getByRole('button', { name: 'Remove Slupsky, Carolyn from AFST' })
    );
    await waitFor(() => expect(deletes).toEqual(['10000001/AFST']));
  });

  it('lists PIs with an additional OrgR first, then PIs with only a default OrgR', async () => {
    mockApi();
    renderTab();

    const section = await screen.findByRole('region', { name: 'PI appointments' });
    const [, first, second] = within(section).getAllByRole('row');
    expect(within(first).getByText('Slupsky, Carolyn')).toBeInTheDocument();
    expect(within(first).getByText('AFST')).toBeInTheDocument();

    // Doe sorts ahead of Slupsky by name but has a single appointment.
    expect(within(second).getByText('Doe, Jane')).toBeInTheDocument();
    expect(within(second).getByText('AARE')).toBeInTheDocument();
    // Her 204 projects are counted even though no appointment skips them yet.
    expect(within(second).getByText('3')).toBeInTheDocument();
    expect(within(second).queryByRole('button')).not.toBeInTheDocument();
    expect(within(section).getAllByRole('row')).toHaveLength(3);
  });

  it('keeps PIs without an additional OrgR last when sorting by that column', async () => {
    mockApi();
    const user = userEvent.setup();
    renderTab();

    const section = await screen.findByRole('region', { name: 'PI appointments' });
    const header = within(section).getByRole('columnheader', { name: /Additional OrgR/ });
    const firstPi = () => within(section).getAllByRole('row')[1];

    await user.click(header);
    expect(header).toHaveAttribute('aria-sort', 'ascending');
    expect(within(firstPi()).getByText('Slupsky, Carolyn')).toBeInTheDocument();

    await user.click(header);
    expect(header).toHaveAttribute('aria-sort', 'descending');
    expect(within(firstPi()).getByText('Slupsky, Carolyn')).toBeInTheDocument();
  });

  it('shows an error instead of a partial list when the PI list fails to load', async () => {
    mockApi();
    server.use(http.get('/api/orgr/pis', () => new HttpResponse(null, { status: 500 })));
    renderTab();

    expect(await screen.findByRole('alert')).toHaveTextContent('Could not load PI appointments.');
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
  });

  it('has no per project placement list or controls', async () => {
    mockApi();
    renderTab();

    await screen.findByRole('region', { name: 'PI appointments' });
    expect(screen.queryByText('Projects on an additional OrgR')).not.toBeInTheDocument();
    expect(screen.getAllByRole('table')).toHaveLength(1);
  });
});
