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

function mockApi(options: { completed?: boolean; unmappedDepartment: boolean; }) {
  let snapshot = createWorkflowSnapshot({
    ...completedUpstream,
    ...(options.completed ? { 'auto-associations': 'Complete', 'orgr-review': 'Complete' } as const : {}),
  });
  let departments = [
    { description: 'ARE', financialDepartment: 'AARE001', hierarchy: [], orgR: 'AARE' },
    { description: 'New', financialDepartment: 'ANEW001', hierarchy: [], orgR: options.unmappedDepartment ? null : 'AARE' },
  ];
  server.use(
    http.get('/api/user/me', () => HttpResponse.json(mockUser)),
    http.get('/api/workflow/snapshot', () =>
      HttpResponse.json(snapshot)
    ),
    http.get('/api/orgr/orgrs', () =>
      HttpResponse.json([{ code: 'AARE', financialDepartmentCount: 0, nifaProjectCount: 0, referenceCount: 1 }])
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
      snapshot = createWorkflowSnapshot(completedUpstream);
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
  it('reopens a completed review after clearing a mapping and locks downstream navigation', async () => {
    mockApi({ completed: true, unmappedDepartment: false });
    const user = userEvent.setup();
    const { cleanup } = renderRoute({ initialPath: '/workflow/orgr-review' });

    try {
      await screen.findByRole('tab', { name: /Financial Departments/ });
      expect(
        screen.queryByRole('button', { name: /Continue to Auto-Associations/ })
      ).not.toBeInTheDocument();
      expect(
        screen.getByRole('link', { name: /Auto-Associations/ })
      ).toBeInTheDocument();
      await user.click(
        screen.getByRole('tab', { name: /Financial Departments/ })
      );
      await user.selectOptions(
        await screen.findByLabelText('OrgR for AARE001'),
        ''
      );

      expect(
        await screen.findByRole('button', {
          name: /Continue to Auto-Associations/,
        })
      ).toBeDisabled();
      expect(
        screen.getByRole('button', { name: /Auto-Associations.*Locked/ })
      ).toBeDisabled();
      expect(
        screen.getByRole('link', { name: /Expense Review.*Complete/ })
      ).toBeInTheDocument();
      await waitFor(() =>
        expect(screen.getByLabelText('OrgR for AARE001')).toBeEnabled()
      );
      expect(
        screen.getByRole('button', { name: /Continue to Auto-Associations/ })
      ).toBeDisabled();

      await user.selectOptions(
        screen.getByLabelText('OrgR for AARE001'),
        'AARE'
      );
      await waitFor(() =>
        expect(
          screen.getByRole('button', { name: /Continue to Auto-Associations/ })
        ).toBeEnabled()
      );
    } finally {
      cleanup();
    }
  });

  it.each([
    { fails: false, financial: true },
    { fails: false, financial: false },
    { fails: true, financial: true },
    { fails: true, financial: false },
  ])(
    'pauses mapping edits through save and refresh ($financial financial, $fails failure)',
    async ({ fails, financial }) => {
      mockApi({ unmappedDepartment: false });
      const save = Promise.withResolvers<void>();
      const refresh = Promise.withResolvers<void>();
      const refreshStarted = Promise.withResolvers<void>();
      let refreshPending = false;
      let savedOrgR = 'AARE';
      const endpoint = financial ? 'financial-departments' : 'nifa-departments';
      const tabName = financial ? /Financial Departments/ : /NIFA Departments/;
      const otherTabName = financial
        ? /NIFA Departments/
        : /Financial Departments/;
      const label = financial ? 'OrgR for AARE001' : 'OrgR for ARE';
      const otherLabel = financial ? 'OrgR for ARE' : 'OrgR for AARE001';
      server.use(
        http.get('/api/orgr/orgrs', () =>
          HttpResponse.json([
            {
              code: 'AARE',
              financialDepartmentCount: 0,
              nifaProjectCount: 0,
              referenceCount: 1,
            },
            {
              code: 'APLS',
              financialDepartmentCount: 0,
              nifaProjectCount: 0,
              referenceCount: 0,
            },
          ])
        ),
        http.get(`/api/orgr/${endpoint}`, () =>
          HttpResponse.json([
            financial
              ? {
                  description: 'ARE',
                  financialDepartment: 'AARE001',
                  hierarchy: [],
                  orgR: savedOrgR,
                }
              : { nifaDepartment: 'ARE', orgR: savedOrgR, projectCount: 2 },
          ])
        ),
        http.patch(`/api/orgr/${endpoint}/:code`, async () => {
          await save.promise;
          refreshPending = true;
          if (fails) {
            return HttpResponse.text('Could not save mapping.', {
              status: 500,
            });
          }
          savedOrgR = 'APLS';
          return new HttpResponse(null, { status: 204 });
        }),
        http.get('/api/workflow/snapshot', async () => {
          if (refreshPending) {
            refreshStarted.resolve();
            await refresh.promise;
          }
          return HttpResponse.json(createWorkflowSnapshot(completedUpstream));
        })
      );
      const user = userEvent.setup();
      const { cleanup } = renderRoute({ initialPath: '/workflow/orgr-review' });

      try {
        await user.click(await screen.findByRole('tab', { name: tabName }));
        const select = await screen.findByLabelText(label);
        await user.selectOptions(select, 'APLS');
        await waitFor(() =>
          expect(screen.getByLabelText(label)).toBeDisabled()
        );
        expect(
          screen.getByRole('button', { name: /Continue to Auto-Associations/ })
        ).toBeDisabled();
        if (!fails) {
          await user.click(screen.getByRole('tab', { name: otherTabName }));
          expect(await screen.findByLabelText(otherLabel)).toBeDisabled();
          await user.click(screen.getByRole('tab', { name: tabName }));
          expect(await screen.findByLabelText(label)).toBeDisabled();
        }

        save.resolve();
        await refreshStarted.promise;
        await waitFor(() =>
          expect(screen.getByLabelText(label)).toHaveValue(
            fails ? 'AARE' : 'APLS'
          )
        );
        expect(screen.getByLabelText(label)).toBeDisabled();
        expect(
          screen.getByRole('button', { name: /Continue to Auto-Associations/ })
        ).toBeDisabled();

        refresh.resolve();
        await waitFor(() => expect(screen.getByLabelText(label)).toBeEnabled());
        expect(
          screen.getByRole('button', { name: /Continue to Auto-Associations/ })
        ).toBeEnabled();
        if (fails) {
          expect(await screen.findByRole('alert')).toHaveTextContent(
            'Could not save mapping.'
          );
        }
      } finally {
        save.resolve();
        refresh.resolve();
        cleanup();
      }
    }
  );

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
