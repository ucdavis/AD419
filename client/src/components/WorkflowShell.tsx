import { useCallback, useRef, useState } from 'react';
import { WorkflowHelpDrawer, type HelpTab } from './WorkflowHelpDrawer.tsx';
import type { WorkflowSnapshot, WorkflowStage } from '../types.ts';
import type { ReactNode } from 'react';
import { StageHeader } from './StageHeader.tsx';
import { WorkflowStepper } from './WorkflowStepper.tsx';
import { WorkflowTopBar } from './WorkflowTopBar.tsx';

export function WorkflowShell({
  children,
  snapshot,
  stage,
}: {
  children: ReactNode;
  snapshot: WorkflowSnapshot;
  stage: WorkflowStage;
}) {
  const [open, setOpen] = useState(false);
  const [tab, setTab] = useState<HelpTab>('documentation');
  const [previousStage, setPreviousStage] = useState(stage.id);
  const opener = useRef<HTMLButtonElement | null>(null);
  const documentationButton = useRef<HTMLButtonElement>(null);
  if (previousStage !== stage.id) {
    setPreviousStage(stage.id);
    setTab('documentation');
  }
  const close = useCallback(() => {
    setOpen(false);
    const target = opener.current?.isConnected
      ? opener.current
      : documentationButton.current;
    target?.focus();
  }, []);
  function show(tab: HelpTab, button: HTMLButtonElement) {
    opener.current = button;
    setTab(tab);
    setOpen(true);
  }
  return (
    <div className="workflow-app">
      <WorkflowTopBar />
      <WorkflowStepper activeStageId={stage.id} snapshot={snapshot} />
      <main className="workflow-main">
        <StageHeader
          actions={
            <>
              <button
                aria-controls="workflow-help"
                aria-expanded={open && tab === 'documentation'}
                className="btn btn-sm"
                onClick={(event) => show('documentation', event.currentTarget)}
                ref={documentationButton}
                type="button"
              >
                Documentation
              </button>
              {stage.id === 'expense-review' ? (
                <button
                  aria-controls="workflow-help"
                  aria-expanded={open && tab === 'assistant'}
                  className="btn btn-primary btn-sm"
                  onClick={(event) => show('assistant', event.currentTarget)}
                  type="button"
                >
                  Ask CAES AI
                </button>
              ) : null}
            </>
          }
          stage={stage}
        />
        {children}
      </main>
      <WorkflowHelpDrawer
        onClose={close}
        onTabChange={setTab}
        open={open}
        stage={stage}
        tab={tab}
      />
    </div>
  );
}
