import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { screen, waitFor } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { createWorkflowSnapshot, server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';

const mockUser = {
  email: 'shannon@example.edu',
  id: 'user-1',
  name: 'Shannon Taylor',
  roles: ['User'],
};

const completedUpstream = {
  'data-classification': 'Complete',
  'data-import': 'Complete',
  'expense-review': 'Complete',
  'orgr-review': 'InProgress',
  'project-identification': 'Complete',
} as const;

function mockApi(options: { unmappedDepartment: boolean }) {
  let departments = [
    { description: 'ARE', financialDepartment: 'AARE001', hierarchy: [], inCycle: true, orgR: 'AARE' },
    { description: 'New', financialDepartment: 'ANEW001', hierarchy: [], inCycle: true, orgR: options.unmappedDepartment ? null : 'AARE' },
  ];
  server.use(
    http.get('/api/user/me', () => HttpResponse.json(mockUser)),
    http.get('/api/workflow/snapshot', () =>
      HttpResponse.json(createWorkflowSnapshot(completedUpstream))
    ),
    http.get('/api/orgr/orgrs', () =>
      HttpResponse.json([{ code: 'AARE', description: 'Ag Econ', referenceCount: 1 }])
    ),
    http.get('/api/orgr/financial-departments', () => HttpResponse.json(departments)),
    http.get('/api/orgr/nifa-departments', () =>
      HttpResponse.json([{ nifaDepartment: 'ARE', orgR: 'AARE', projectCount: 2 }])
    ),
    http.get('/api/orgr/projects', () => HttpResponse.json([])),
    http.patch('/api/orgr/financial-departments/:code', async ({ params, request }) => {
      const body = (await request.json()) as { orgR: string | null };
      departments = departments.map((d) =>
        d.financialDepartment === params.code ? { ...d, orgR: body.orgR } : d
      );
      return new HttpResponse(null, { status: 204 });
    }),
    http.put('/api/workflow/stages/orgr-review', () =>
      HttpResponse.json(
        createWorkflowSnapshot({ ...completedUpstream, 'orgr-review': 'Complete' })
      )
    )
  );
}

describe('OrgR Review stage', () => {
  it('renders the four tabs with a needs-review badge', async () => {
    mockApi({ unmappedDepartment: true });
    const { cleanup } = renderRoute({ initialPath: '/workflow/orgr-review' });

    try {
      expect(await screen.findByRole('tab', { name: /OrgR List/ })).toBeInTheDocument();
      expect(screen.getByRole('tab', { name: /Financial Departments/ })).toHaveTextContent('1 needs review');
      expect(screen.getByRole('tab', { name: /NIFA Departments/ })).toBeInTheDocument();
      expect(screen.getByRole('tab', { name: /Project OrgRs/ })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Continue to Auto-Associations/ })).toBeDisabled();
    } finally {
      cleanup();
    }
  });

  it('closes the gate and shows an alert when a department fetch fails', async () => {
    mockApi({ unmappedDepartment: false });
    server.use(
      http.get('/api/orgr/financial-departments', () =>
        HttpResponse.text('boom', { status: 500 })
      )
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/orgr-review' });

    try {
      const alert = await screen.findByRole('alert');
      expect(alert).toHaveTextContent('boom');
      expect(
        screen.getByRole('button', { name: /Continue to Auto-Associations/ })
      ).toBeDisabled();
    } finally {
      cleanup();
    }
  });

  it('enables Continue when everything is mapped and advances the workflow', async () => {
    mockApi({ unmappedDepartment: false });
    const user = userEvent.setup();
    const { cleanup, router } = renderRoute({ initialPath: '/workflow/orgr-review' });

    try {
      const button = await screen.findByRole('button', { name: /Continue to Auto-Associations/ });
      await waitFor(() => expect(button).toBeEnabled());
      await user.click(button);
      await waitFor(() =>
        expect(router.state.location.pathname).toBe('/workflow/auto-associations')
      );
    } finally {
      cleanup();
    }
  });
});
