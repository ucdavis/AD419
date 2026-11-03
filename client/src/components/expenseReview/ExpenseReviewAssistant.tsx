import { buildExpenseReviewClientTools } from '@/components/expenseReview/expenseReviewAssistantTools.ts';
import type { ExpenseReviewSearch } from '@/components/expenseReview/expenseReviewSearch.ts';
import { fetchJson } from '@/lib/api.ts';
import {
  AssistantProvider,
  type AssistantSession,
  type AssistantUiBridge,
} from '@ucdavis/caes-ai-assistant-react';
import { AssistantInline } from '@ucdavis/caes-ai-assistant-react/ui';
import '@ucdavis/caes-ai-assistant-react/theme.css';
import { createPortal } from 'react-dom';
import { useQueryClient } from '@tanstack/react-query';
import { getRouteApi } from '@tanstack/react-router';
import { useCallback, useEffect, useMemo, useState } from 'react';

const routeApi = getRouteApi('/(authenticated)/workflow/$stageId');

function createAssistantSession() {
  return fetchJson<AssistantSession>('/api/assistant/session', {
    method: 'POST',
  });
}

export interface Toast {
  level: 'error' | 'info' | 'success';
  message: string;
}

const TOAST_CLASS: Record<Toast['level'], string> = {
  error: 'alert-error',
  info: 'alert-info',
  success: 'alert-success',
};

const TOAST_DURATION_MS = 4000;

export function AssistantToast({
  onDismiss,
  toast,
}: {
  onDismiss: () => void;
  toast: Toast | null;
}) {
  useEffect(() => {
    if (!toast) {
      return;
    }
    const timerId = window.setTimeout(onDismiss, TOAST_DURATION_MS);
    return () => window.clearTimeout(timerId);
  }, [onDismiss, toast]);

  if (!toast) {
    return null;
  }

  return (
    <div className="toast toast-end">
      <div className={`alert ${TOAST_CLASS[toast.level]}`} role="status">
        <span>{toast.message}</span>
      </div>
    </div>
  );
}

export function ExpenseReviewAssistant() {
  const search = routeApi.useSearch();
  const navigate = routeApi.useNavigate();
  const queryClient = useQueryClient();
  const [toast, setToast] = useState<Toast | null>(null);

  const clientTools = useMemo(
    () =>
      buildExpenseReviewClientTools({
        getSearch: () => search,
        setSearch: (patch) => {
          void navigate({
            replace: true,
            search: (previous: ExpenseReviewSearch) => ({
              ...previous,
              ...patch,
            }),
            to: '.',
          });
        },
      }),
    [navigate, search]
  );

  const dismissToast = useCallback(() => setToast(null), []);

  const uiBridge = useMemo<AssistantUiBridge>(
    () => ({
      invalidateQuery: (key) =>
        queryClient.invalidateQueries({ queryKey: [...key] }),
      showToast: (level, message) => setToast({ level, message }),
    }),
    [queryClient]
  );

  return (
    <AssistantProvider
      clientTools={clientTools}
      createSession={createAssistantSession}
      title="Expense Review Assistant"
      uiBridge={uiBridge}
    >
      <div className="expense-review-assistant h-full">
        <AssistantInline
          composerProps={{ placeholder: 'Ask about expense review' }}
        />
        {createPortal(
          <AssistantToast onDismiss={dismissToast} toast={toast} />,
          document.body
        )}
      </div>
    </AssistantProvider>
  );
}
