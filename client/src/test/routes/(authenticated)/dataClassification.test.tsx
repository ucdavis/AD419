import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { fireEvent, screen, waitFor } from '@testing-library/react';
import { server } from '@/test/mswUtils.ts';
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

function mockApi() {
  let current = [...segments];
  server.use(
    http.get('/api/user/me', () => HttpResponse.json(mockUser)),
    http.get('/api/chartstringsegments', () => HttpResponse.json(current)),
    http.patch('/api/chartstringsegments', async ({ request }) => {
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
          screen.getByRole('link', { name: /Continue to Expense Review/ })
        ).toBeInTheDocument();
      });
    } finally {
      cleanup();
    }
  });
});
