import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { fireEvent, screen, waitFor } from '@testing-library/react';
import { createWorkflowSnapshot, server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';

const mockUser = {
  email: 'shannon@example.edu',
  id: 'user-1',
  name: 'Shannon Taylor',
  roles: ['User'],
};

const segments: {
  code: string;
  description: string;
  hierarchy: { code: string; level: string; name: string | null }[];
  includeInReport: boolean | null;
  segmentType: string;
  sfn: string | null;
}[] = [
  { code: '45530', description: 'AES', hierarchy: [], includeInReport: true, segmentType: 'Fund', sfn: '220' },
  { code: '70575', description: 'Berry', hierarchy: [], includeInReport: null, segmentType: 'Fund', sfn: null },
];

const staffTypes = [
  { description: 'Scientist', fteSfn: '241', staffTypeCode: '1S' },
  { description: 'Technical Support', fteSfn: '243', staffTypeCode: '3T' },
];

interface MockJobCode {
  amount: number;
  blocking: boolean;
  employeeCount: number;
  fte: number;
  fteSfn: string | null;
  jobCode: string;
  staffTypeCode: string | null;
  titleName: string | null;
}

const jobCodeRow = (jobCode: string, overrides: Partial<MockJobCode> = {}): MockJobCode => ({
  amount: 100,
  blocking: false,
  employeeCount: 1,
  fte: 0.25,
  fteSfn: null,
  jobCode,
  staffTypeCode: null,
  titleName: null,
  ...overrides,
});

const jobCodesResponse = (rows: MockJobCode[]) => ({
  cycleEnd: '2026-09-30',
  cycleStart: '2025-10-01',
  fiscalYear: 'FY26',
  rows,
  staffTypes,
});

const allClassifiedSegments = segments.map((segment) => ({
  ...segment,
  includeInReport: true,
  sfn: segment.segmentType === 'Fund' ? '201' : null,
}));

function mockApi(options: { jobCodes?: MockJobCode[]; segments?: typeof segments } = {}) {
  let current = [...(options.segments ?? segments)];
  let jobCodes = [...(options.jobCodes ?? [])];
  server.use(
    http.get('/api/user/me', () => HttpResponse.json(mockUser)),
    http.get('/api/workflow/snapshot', () =>
      HttpResponse.json(
        createWorkflowSnapshot({
          'data-classification': 'InProgress',
          'data-import': 'Complete',
          'project-identification': 'Complete',
        })
      )
    ),
    http.get('/api/segmentclassifications', () => HttpResponse.json(current)),
    http.get('/api/jobcodeclassifications', () => HttpResponse.json(jobCodesResponse(jobCodes))),
    http.patch('/api/jobcodeclassifications', async ({ request }) => {
      const body = await request.json() as { jobCode: string; staffTypeCode: string };
      const option = staffTypes.find((staffType) => staffType.staffTypeCode === body.staffTypeCode);
      jobCodes = jobCodes.map((row) =>
        row.jobCode === body.jobCode
          ? { ...row, blocking: false, fteSfn: option?.fteSfn ?? null, staffTypeCode: body.staffTypeCode }
          : row
      );
      return new HttpResponse(null, { status: 204 });
    }),
    http.patch('/api/segmentclassifications', async ({ request }) => {
      const body = await request.json() as { code: string; includeInReport: boolean; segmentType: string; sfn: string | null };
      current = current.map((s) =>
        s.code === body.code ? { ...s, includeInReport: body.includeInReport } : s
      );
      return new HttpResponse(null, { status: 204 });
    })
  );
}

describe('Data Classification stage', () => {
  it('renders the classifier with tabs instead of the placeholder', async () => {
    mockApi();
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });

    try {
      expect(await screen.findByRole('tab', { name: /Fund/ })).toBeInTheDocument();
      expect(screen.getByRole('tab', { name: /Financial Dept/ })).toBeInTheDocument();
      expect(screen.queryByRole('heading', { name: 'Coming soon' })).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('blocks Continue until every segment is classified, then opens the gate', async () => {
    mockApi();
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });

    try {
      const fundTab = await screen.findByRole('tab', { name: /Fund/ });
      fireEvent.click(fundTab);

      await screen.findByText('70575');

      expect(
        screen.getByRole('button', { name: /Continue to Expense Review/ })
      ).toBeDisabled();

      const dropdowns = screen.getAllByRole<HTMLSelectElement>('combobox');
      const unsetDropdown = dropdowns.find((dropdown) => dropdown.value === '');
      fireEvent.change(unsetDropdown!, { target: { value: '201' } });

      await waitFor(() => {
        expect(
          screen.getByRole('button', { name: /Continue to Expense Review/ })
        ).toBeEnabled();
      });
    } finally {
      cleanup();
    }
  });

  it('continues to expense review after updating the workflow stage', async () => {
    let updateRequests = 0;
    server.use(
      http.get('/api/user/me', () => HttpResponse.json(mockUser)),
      http.get('/api/workflow/snapshot', () =>
        HttpResponse.json(
          createWorkflowSnapshot({
            'data-classification': updateRequests > 0 ? 'Complete' : 'InProgress',
            'data-import': 'Complete',
            'expense-review': updateRequests > 0 ? 'InProgress' : 'NotStarted',
            'project-identification': 'Complete',
          })
        )
      ),
      http.get('/api/segmentclassifications', () =>
        HttpResponse.json(
          segments.map((segment) => ({
            ...segment,
            includeInReport: true,
            sfn: segment.segmentType === 'Fund' ? '201' : null,
          }))
        )
      ),
      http.get('/api/jobcodeclassifications', () => HttpResponse.json(jobCodesResponse([]))),
      http.get('/api/expensereview/filters', () =>
        HttpResponse.json({
          accounts: [],
          activities: [],
          aeProjects: [],
          entities: [],
          exclusionReasons: [],
          financialDepts: [],
          funds: [],
          programs: [],
          purposes: [],
          sfns: [],
        })
      ),
      http.get('/api/expensereview/transactions', () =>
        HttpResponse.json({
          counts: { all: 0, excluded: 0, included: 0 },
          cycleEnd: '2026-09-30',
          cycleStart: '2025-10-01',
          fiscalYear: 'FY26',
          page: 1,
          pageCount: 0,
          pageSize: 25,
          rows: [],
          totalCount: 0,
        })
      ),
      http.put('/api/workflow/stages/:stageId', async ({ params, request }) => {
        expect(params.stageId).toBe('data-classification');
        expect(await request.json()).toEqual({ status: 'Complete' });
        updateRequests += 1;
        return HttpResponse.json(
          createWorkflowSnapshot({
            'data-classification': 'Complete',
            'data-import': 'Complete',
            'expense-review': 'InProgress',
            'project-identification': 'Complete',
          })
        );
      })
    );
    const { cleanup, router } = renderRoute({
      initialPath: '/workflow/data-classification',
    });

    try {
      fireEvent.click(
        await screen.findByRole('button', {
          name: /continue to expense review/i,
        })
      );

      await waitFor(() => {
        expect(updateRequests).toBe(1);
        expect(router.state.location.pathname).toBe('/workflow/expense-review');
      });
    } finally {
      cleanup();
    }
  });

  it('shows the Job Code tab with a badge for blocking job codes', async () => {
    mockApi({
      jobCodes: [
        jobCodeRow('0000', { blocking: true }),
        jobCodeRow('4448', { blocking: true }),
        jobCodeRow('4446'),
        jobCodeRow('1234', { fteSfn: '241', staffTypeCode: '1S', titleName: 'PROFESSOR' }),
      ],
    });
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });

    try {
      const tab = await screen.findByRole('tab', { name: /Job Code/ });
      await waitFor(() => expect(tab).toHaveTextContent('2 new'));
      const tabs = screen.getAllByRole('tab');
      expect(tabs.at(-1)).toBe(tab);

      fireEvent.click(tab);

      expect(tab).toHaveAttribute('aria-selected', 'true');
      expect(
        await screen.findByText(
          'The job SFN is the FTE line a job code reports on. Dollars are included either way. Without a line the FTE cannot be reported and State Appropriations (13U02) dollars cannot be auto-associated. Changes made after auto-associations have run apply when they are rebuilt.'
        )
      ).toBeInTheDocument();
      expect(screen.getByRole('combobox', { name: 'Job SFN for 0000' })).toBeInTheDocument();
      expect(screen.getByText('PROFESSOR')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Export/ })).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('blocks Continue while a blocking job code is unassigned', async () => {
    mockApi({
      jobCodes: [jobCodeRow('0000', { blocking: true }), jobCodeRow('4446')],
      segments: allClassifiedSegments,
    });
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });

    try {
      const tab = await screen.findByRole('tab', { name: /Job Code/ });
      await waitFor(() => expect(tab).toHaveTextContent('1 new'));
      expect(screen.getByRole('button', { name: /Continue to Expense Review/ })).toBeDisabled();
      expect(
        screen.getByText('Unclassified rows must be set before the next step.')
      ).toBeInTheDocument();

      fireEvent.click(tab);
      fireEvent.change(await screen.findByRole('combobox', { name: 'Job SFN for 0000' }), {
        target: { value: '1S' },
      });

      // 4446 is still unassigned, but it does not block.
      await waitFor(() => {
        expect(screen.getByRole('button', { name: /Continue to Expense Review/ })).toBeEnabled();
      });
      expect(screen.getByText('All segments classified.')).toBeInTheDocument();
      expect(tab).not.toHaveTextContent('new');
      expect(screen.getByRole<HTMLSelectElement>('combobox', { name: 'Job SFN for 0000' }).value).toBe('1S');
    } finally {
      cleanup();
    }
  });

  it('keeps Continue disabled when job codes cannot be loaded', async () => {
    mockApi({ segments: allClassifiedSegments });
    server.use(
      http.get('/api/jobcodeclassifications', () =>
        HttpResponse.text('No fiscal period has been confirmed in Project Identification.', {
          status: 409,
        })
      )
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });

    try {
      const tab = await screen.findByRole('tab', { name: /Job Code/ });
      fireEvent.click(tab);

      const alert = await screen.findByRole('alert');
      expect(alert).toHaveTextContent('No fiscal period has been confirmed in Project Identification.');
      expect(screen.getByRole('button', { name: /Continue to Expense Review/ })).toBeDisabled();
      expect(screen.queryByText('All segments classified.')).not.toBeInTheDocument();
    } finally {
      cleanup();
    }
  });

  it('rolls back the selection when the save fails', async () => {
    mockApi({
      jobCodes: [jobCodeRow('0000', { blocking: true })],
      segments: allClassifiedSegments,
    });
    server.use(
      http.patch('/api/jobcodeclassifications', () =>
        HttpResponse.text("Unknown staff type '1S'.", { status: 400 })
      )
    );
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });

    try {
      fireEvent.click(await screen.findByRole('tab', { name: /Job Code/ }));
      const select = await screen.findByRole<HTMLSelectElement>('combobox', { name: 'Job SFN for 0000' });
      fireEvent.change(select, { target: { value: '1S' } });

      const alert = await screen.findByRole('alert');
      expect(alert).toHaveTextContent("Unknown staff type '1S'.");
      await waitFor(() =>
        expect(screen.getByRole<HTMLSelectElement>('combobox', { name: 'Job SFN for 0000' }).value).toBe('')
      );
      expect(screen.getByRole('button', { name: /Continue to Expense Review/ })).toBeDisabled();
    } finally {
      cleanup();
    }
  });

  it('shows the FTE disclaimer only on the ERN tab', async () => {
    mockApi();
    const { cleanup } = renderRoute({ initialPath: '/workflow/data-classification' });

    try {
      await screen.findByRole('tab', { name: /Fund/ });
      expect(
        screen.queryByText(/affects fte calculations only/i)
      ).not.toBeInTheDocument();

      fireEvent.click(screen.getByRole('tab', { name: /ERN/ }));

      expect(
        await screen.findByText(/affects fte calculations only/i)
      ).toBeInTheDocument();
    } finally {
      cleanup();
    }
  });
});
