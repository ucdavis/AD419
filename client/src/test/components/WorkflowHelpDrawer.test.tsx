import { WorkflowShell } from '@/components/WorkflowShell.tsx';
import { createWorkflowSnapshot, server } from '@/test/mswUtils.ts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { act, render, screen, waitFor } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('@/components/WorkflowTopBar.tsx', () => ({
  WorkflowTopBar: () => null,
}));
vi.mock('@/components/WorkflowStepper.tsx', () => ({
  WorkflowStepper: () => null,
}));
vi.mock('@/components/expenseReview/ExpenseReviewAssistant.tsx', () => ({
  ExpenseReviewAssistant: () => <input aria-label="Assistant draft" />,
}));

const snapshot = createWorkflowSnapshot();
let desktop = true;
function setup(stageIndex = 0) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  const ui = (index: number) => (
    <QueryClientProvider client={queryClient}>
      <WorkflowShell snapshot={snapshot} stage={snapshot.stages[index]}>
        <p>Working area</p>
      </WorkflowShell>
    </QueryClientProvider>
  );
  const result = render(ui(stageIndex));
  return { ...result, navigate: (index: number) => result.rerender(ui(index)) };
}

describe('Workflow help drawer', () => {
  beforeEach(() => {
    desktop = true;
    vi.stubGlobal('matchMedia', () => ({
      addEventListener: vi.fn(),
      matches: desktop,
      removeEventListener: vi.fn(),
    }));
  });
  afterEach(() => vi.unstubAllGlobals());

  it('lazily fetches and shows the right note for all ten stages while retaining open state', async () => {
    let requests = 0;
    server.use(
      http.get('/api/workflow/documentation', () => {
        requests++;
        return HttpResponse.json(
          Object.fromEntries(
            snapshot.stages.map((stage) => [
              stage.id,
              {
                embedUrl: `https://box.com/embed/${stage.id}`,
                url: `https://box.com/notes/${stage.id}`,
              },
            ])
          )
        );
      })
    );
    const user = userEvent.setup();
    const { navigate } = setup();
    expect(requests).toBe(0);
    expect(document.querySelector('iframe')).toBeNull();
    expect(screen.queryByRole('complementary')).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Documentation' }));
    for (const [index, stage] of snapshot.stages.entries()) {
      navigate(index);
      expect(
        await screen.findByTitle(`${stage.title} documentation`)
      ).toHaveAttribute('src', `https://box.com/embed/${stage.id}`);
      expect(screen.getByRole('link', { name: 'Open in Box' })).toHaveAttribute(
        'href',
        `https://box.com/notes/${stage.id}`
      );
    }
    expect(requests).toBe(1);
  });

  it('supports retry, missing configuration, mobile fallback, expansion, Escape and focus restoration', async () => {
    server.use(
      http.get(
        '/api/workflow/documentation',
        () => new HttpResponse(null, { status: 503 })
      )
    );
    const user = userEvent.setup();
    const { navigate } = setup();
    const opener = screen.getByRole('button', { name: 'Documentation' });
    await user.click(opener);
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Documentation could not be loaded'
    );
    server.use(
      http.get('/api/workflow/documentation', () => HttpResponse.json({}))
    );
    await user.click(screen.getByRole('button', { name: 'Retry' }));
    await screen.findByText(
      'Documentation has not been configured for this stage.'
    );
    await user.click(
      screen.getByRole('button', { name: 'Expand help drawer' })
    );
    expect(screen.getByRole('complementary')).toHaveClass('md:w-[48rem]');
    await user.keyboard('{Escape}');
    expect(opener).toHaveFocus();
    expect(screen.queryByRole('complementary')).not.toBeInTheDocument();
    desktop = false;
    server.use(
      http.get('/api/workflow/documentation', () => HttpResponse.json({}))
    );
    navigate(1);
    await user.click(opener);
    expect(document.querySelector('iframe')).toBeNull();
  });

  it('keeps Open in Box without loading an iframe below the tablet breakpoint', async () => {
    desktop = false;
    const stage = snapshot.stages[0];
    server.use(
      http.get('/api/workflow/documentation', () =>
        HttpResponse.json({
          [stage.id]: {
            embedUrl: 'https://box.com/embed/mobile',
            url: 'https://box.com/notes/mobile',
          },
        })
      )
    );
    const user = userEvent.setup();
    setup();
    await user.click(screen.getByRole('button', { name: 'Documentation' }));
    expect(
      await screen.findByRole('link', { name: 'Open in Box' })
    ).toHaveAttribute('href', 'https://box.com/notes/mobile');
    expect(document.querySelector('iframe')).toBeNull();
  });

  it('uses roving tabs and disposes the assistant when leaving Expense Review', async () => {
    server.use(
      http.get('/api/workflow/documentation', () => HttpResponse.json({}))
    );
    const expenseIndex = snapshot.stages.findIndex(
      (stage) => stage.id === 'expense-review'
    );
    const user = userEvent.setup();
    const { navigate } = setup(expenseIndex);
    expect(screen.queryByRole('textbox')).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Documentation' }));
    const docs = screen.getByRole('tab', { name: 'Documentation' });
    expect(docs).toHaveFocus();
    await user.keyboard('{ArrowRight}');
    expect(screen.getByRole('tab', { name: 'Ask CAES AI' })).toHaveFocus();
    await user.type(screen.getByRole('textbox'), 'draft');
    await user.click(docs);
    expect(screen.queryByRole('textbox')).not.toBeInTheDocument();
    await user.click(screen.getByRole('tab', { name: 'Ask CAES AI' }));
    expect(screen.getByRole('textbox')).toHaveValue('draft');
    await act(() => navigate(0));
    await waitFor(() =>
      expect(
        screen.getByRole('tab', { name: 'Documentation' })
      ).toHaveAttribute('aria-selected', 'true')
    );
    expect(document.querySelector('input')).toBeNull();
  });
});
