import { ExpenseReviewAssistant } from '@/components/expenseReview/ExpenseReviewAssistant.tsx';
import { stageDocumentationQueryOptions } from '@/queries/stageDocumentation.ts';
import type { WorkflowStage } from '@/types.ts';
import { useQuery } from '@tanstack/react-query';
import { useEffect, useRef, useState, type KeyboardEvent } from 'react';

export type HelpTab = 'documentation' | 'assistant';

function Documentation({ stage }: { stage: WorkflowStage }) {
  const query = useQuery(stageDocumentationQueryOptions());
  const [desktop, setDesktop] = useState(
    () => window.matchMedia('(min-width: 768px)').matches
  );
  useEffect(() => {
    const media = window.matchMedia('(min-width: 768px)');
    const update = () => setDesktop(media.matches);
    media.addEventListener('change', update);
    return () => media.removeEventListener('change', update);
  }, []);
  if (query.isPending) {
    return <p role="status">Loading documentation…</p>;
  }
  if (query.isError) {
    return (
      <div role="alert">
        <p>Documentation could not be loaded.</p>
        <button
          className="btn btn-sm"
          onClick={() => void query.refetch()}
          type="button"
        >
          Retry
        </button>
      </div>
    );
  }
  const note = query.data[stage.id];
  if (!note) {
    return <p>Documentation has not been configured for this stage.</p>;
  }
  return (
    <div className="flex h-full flex-col gap-3">
      <a
        className="btn btn-primary btn-sm self-start"
        href={note.url}
        rel="noreferrer"
        target="_blank"
      >
        Open in Box
      </a>
      <p className="text-sm">
        Use Open in Box to edit or if the embedded note cannot be displayed. Box
        controls sign-in and access.
      </p>
      {desktop ? (
        <iframe
          className="min-h-80 w-full flex-1 border-0"
          sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-popups-to-escape-sandbox"
          src={note.embedUrl}
          title={`${stage.title} documentation`}
        />
      ) : null}
    </div>
  );
}

export function WorkflowHelpDrawer({
  onClose,
  onTabChange,
  open,
  stage,
  tab,
}: {
  onClose: () => void;
  onTabChange: (tab: HelpTab) => void;
  open: boolean;
  stage: WorkflowStage;
  tab: HelpTab;
}) {
  const [expanded, setExpanded] = useState(false);
  const [assistantMounted, setAssistantMounted] = useState(false);
  const documentationTab = useRef<HTMLButtonElement>(null);
  const assistantTab = useRef<HTMLButtonElement>(null);
  const isExpenseReview = stage.id === 'expense-review';
  const assistantVisible = open && tab === 'assistant' && isExpenseReview;
  if (assistantVisible && !assistantMounted) {
    setAssistantMounted(true);
  }
  if (!isExpenseReview && assistantMounted) {
    setAssistantMounted(false);
  }
  const selectedTab = tab === 'assistant' ? assistantTab : documentationTab;
  useEffect(() => {
    if (open) {
      selectedTab.current?.focus();
    }
  }, [open, selectedTab]);
  useEffect(() => {
    if (!open) {
      return;
    }
    const dismiss = (event: globalThis.KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        onClose();
      }
    };
    document.addEventListener('keydown', dismiss);
    return () => document.removeEventListener('keydown', dismiss);
  }, [onClose, open]);
  function handleTabKey(event: KeyboardEvent<HTMLButtonElement>) {
    if (
      !isExpenseReview ||
      !['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)
    ) {
      return;
    }
    event.preventDefault();
    const next =
      event.key === 'Home'
        ? 'documentation'
        : event.key === 'End'
          ? 'assistant'
          : tab === 'documentation'
            ? 'assistant'
            : 'documentation';
    onTabChange(next);
    (next === 'assistant' ? assistantTab : documentationTab).current?.focus();
  }
  return (
    <aside
      aria-label="Stage help"
      className={`fixed inset-y-0 right-0 z-50 ${open ? 'flex' : 'hidden'} w-full max-w-full flex-col border-l border-slate-300 bg-white shadow-xl ${expanded ? 'md:w-[48rem]' : 'md:w-[28rem]'}`}
      hidden={!open}
      id="workflow-help"
      inert={!open}
    >
      <div className="flex items-center justify-between gap-2 border-b p-3">
        <h2 className="font-bold">{stage.title} help</h2>
        <div className="flex gap-2">
          <button
            aria-label={
              expanded ? 'Collapse help drawer' : 'Expand help drawer'
            }
            aria-pressed={expanded}
            className="btn btn-sm hidden md:inline-flex"
            onClick={() => setExpanded(!expanded)}
            type="button"
          >
            {expanded ? 'Collapse' : 'Expand'}
          </button>
          <button
            aria-label="Close help drawer"
            className="btn btn-sm"
            onClick={onClose}
            type="button"
          >
            Close
          </button>
        </div>
      </div>
      <div
        aria-label="Stage help"
        className="flex gap-2 border-b p-3"
        role="tablist"
      >
        <button
          aria-controls="documentation-panel"
          aria-selected={tab === 'documentation'}
          className="btn btn-sm"
          id="documentation-tab"
          onClick={() => onTabChange('documentation')}
          onKeyDown={handleTabKey}
          ref={documentationTab}
          role="tab"
          tabIndex={tab === 'documentation' ? 0 : -1}
          type="button"
        >
          Documentation
        </button>
        {isExpenseReview ? (
          <button
            aria-controls="assistant-panel"
            aria-selected={tab === 'assistant'}
            className="btn btn-sm"
            id="assistant-tab"
            onClick={() => onTabChange('assistant')}
            onKeyDown={handleTabKey}
            ref={assistantTab}
            role="tab"
            tabIndex={tab === 'assistant' ? 0 : -1}
            type="button"
          >
            Ask CAES AI
          </button>
        ) : null}
      </div>
      <div
        aria-labelledby="documentation-tab"
        className="min-h-0 flex-1 overflow-auto p-4"
        hidden={tab !== 'documentation'}
        id="documentation-panel"
        role="tabpanel"
        tabIndex={0}
      >
        {open && tab === 'documentation' ? (
          <Documentation stage={stage} />
        ) : null}
      </div>
      {isExpenseReview ? (
        <div
          aria-labelledby="assistant-tab"
          className="min-h-0 flex-1 overflow-auto"
          hidden={!assistantVisible}
          id="assistant-panel"
          inert={!assistantVisible}
          role="tabpanel"
          tabIndex={0}
        >
          {assistantMounted ? <ExpenseReviewAssistant /> : null}
        </div>
      ) : null}
    </aside>
  );
}
