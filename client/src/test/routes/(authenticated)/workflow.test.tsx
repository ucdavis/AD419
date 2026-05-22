import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { screen, waitFor } from '@testing-library/react';
import { server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';

const mockUser = {
  email: 'shannon@example.edu',
  id: 'user-1',
  name: 'Shannon Taylor',
  roles: ['User'],
};

describe('AD419 workflow routes', () => {
  it('redirects the authenticated homepage to the current workflow stage', async () => {
    server.use(
      http.get('/api/user/me', () => {
        return HttpResponse.json(mockUser);
      })
    );

    const { cleanup, router } = renderRoute({ initialPath: '/' });

    try {
      expect(
        await screen.findByRole('heading', { name: 'Expense Review' })
      ).toBeInTheDocument();

      await waitFor(() => {
        expect(router.state.location.pathname).toBe('/workflow/expense-review');
      });
    } finally {
      cleanup();
    }
  });

  it('redirects locked workflow stage URLs to the current workflow stage', async () => {
    server.use(
      http.get('/api/user/me', () => {
        return HttpResponse.json(mockUser);
      })
    );

    const { cleanup, router } = renderRoute({
      initialPath: '/workflow/final-reports',
    });

    try {
      expect(
        await screen.findByRole('heading', { name: 'Expense Review' })
      ).toBeInTheDocument();

      await waitFor(() => {
        expect(router.state.location.pathname).toBe('/workflow/expense-review');
      });
    } finally {
      cleanup();
    }
  });
});
