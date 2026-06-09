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
  it('redirects the authenticated homepage to the first workflow stage', async () => {
    server.use(
      http.get('/api/user/me', () => {
        return HttpResponse.json(mockUser);
      })
    );

    const { cleanup, router } = renderRoute({ initialPath: '/' });

    try {
      expect(
        await screen.findByRole('heading', { name: 'Project Identification' })
      ).toBeInTheDocument();

      // Every step is a "Coming soon" placeholder.
      expect(
        await screen.findByRole('heading', { name: 'Coming soon' })
      ).toBeInTheDocument();

      await waitFor(() => {
        expect(router.state.location.pathname).toBe(
          '/workflow/project-identification'
        );
      });
    } finally {
      cleanup();
    }
  });

  it('loads any workflow stage directly without locking', async () => {
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
        await screen.findByRole('heading', { name: 'Final Reports' })
      ).toBeInTheDocument();

      expect(
        await screen.findByRole('heading', { name: 'Coming soon' })
      ).toBeInTheDocument();

      await waitFor(() => {
        expect(router.state.location.pathname).toBe('/workflow/final-reports');
      });
    } finally {
      cleanup();
    }
  });
});
