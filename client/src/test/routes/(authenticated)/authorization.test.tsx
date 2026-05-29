import { describe, expect, it, vi } from 'vitest';
import { screen } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import { server } from '@/test/mswUtils.ts';
import { renderRoute } from '@/test/routerUtils.tsx';

describe('authenticated route authorization', () => {
  it('renders a not-authorized message when the current user is forbidden', async () => {
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
    const consoleWarn = vi.spyOn(console, 'warn').mockImplementation(() => {});

    server.use(
      http.get('/api/user/me', () =>
        HttpResponse.json({ message: 'Forbidden' }, { status: 403 })
      )
    );

    const { cleanup } = renderRoute({ initialPath: '/me' });

    try {
      expect(
        await screen.findByText(/not authorized to access ad419/i)
      ).toBeInTheDocument();
      expect(
        screen.queryByText(/failed to load user data/i)
      ).not.toBeInTheDocument();
    } finally {
      consoleError.mockRestore();
      consoleWarn.mockRestore();
      cleanup();
    }
  });
});
