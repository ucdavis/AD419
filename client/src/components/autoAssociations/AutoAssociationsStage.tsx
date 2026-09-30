import { useState } from 'react';
import {
  AUTO_ASSOCIATIONS_TABS,
  type AutoAssociationsTabId,
  buildExists,
} from './autoAssociationsTabs.ts';
import { autoAssociationBuildQueryOptions } from '@/queries/autoAssociations.ts';
import { apiErrorMessage } from '@/queries/orgr.ts';
import { WORKFLOW_SNAPSHOT_KEY, updateWorkflowStageStatus } from '@/queries.ts';
import type { WorkflowStageStatus } from '@/types.ts';
import { useNavigate } from '@tanstack/react-router';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

export const EMPTY_STATE_TEXT =
  'No auto-association build exists for this cycle. Reopen OrgR Review and mark it complete to build.';

export function AutoAssociationsStage({ status }: { status: WorkflowStageStatus }) {
  const {
    data: build,
    error: buildError,
    isError: buildIsError,
    isLoading: buildLoading,
  } = useQuery(autoAssociationBuildQueryOptions());
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const [activeId, setActiveId] = useState<AutoAssociationsTabId>(AUTO_ASSOCIATIONS_TABS[0].id);
  const continueMutation = useMutation({
    mutationFn: () => updateWorkflowStageStatus('auto-associations', 'Complete'),
    onSuccess: (snapshot) => {
      queryClient.setQueryData(WORKFLOW_SNAPSHOT_KEY, snapshot);
      void navigate({
        params: { stageId: 'manual-associations' },
        to: '/workflow/$stageId',
      });
    },
  });

  if (buildLoading) {
    return <p role="status">Loading auto-associations...</p>;
  }

  const gateOpen = !buildIsError && buildExists(build);
  const isComplete = status === 'Complete';
  const activeTab = AUTO_ASSOCIATIONS_TABS.find((tab) => tab.id === activeId) ?? AUTO_ASSOCIATIONS_TABS[0];

  return (
    <div className="space-y-4">
      <p>
        The rules engine ran when OrgR Review was completed. Review what it
        associated and what it could not, then continue to manual
        associations.
      </p>

      {buildIsError ? (
        <div className="alert alert-error" role="alert">
          <span>{apiErrorMessage(buildError, 'Could not load the auto-association build.')}</span>
        </div>
      ) : null}

      {!buildIsError && !gateOpen ? (
        <p className="text-warning" role="status">
          {EMPTY_STATE_TEXT}
        </p>
      ) : null}

      {gateOpen && build ? (
        <>
          <p className="text-sm text-base-content/70">
            Built {new Date(build.builtAt).toLocaleString()}: {build.summaryRows} expense groups,{' '}
            {build.associationRows} associations, {build.excludedProjects} projects under $100,{' '}
            {build.misclassified204Rows} misclassified 204 rows.
          </p>

          <div className="tabs tabs-bordered" role="tablist">
            {AUTO_ASSOCIATIONS_TABS.map((tab) => (
              <button
                aria-selected={activeId === tab.id}
                className={`tab ${activeId === tab.id ? 'tab-active' : ''}`}
                key={tab.id}
                onClick={() => setActiveId(tab.id)}
                role="tab"
                type="button"
              >
                {tab.label}
              </button>
            ))}
          </div>

          <div className="alert alert-info" role="note">
            <span>{activeTab.note}</span>
          </div>

          {/* Task 5 replaces this block with one component per tab. */}
          <p role="status">Report coming in the next task: {activeTab.label}</p>
        </>
      ) : null}

      <div className="flex items-center justify-between border-t pt-4">
        <span className={gateOpen ? 'text-success' : 'text-warning'}>
          {gateOpen
            ? 'A build exists for this cycle.'
            : 'Auto-associations must be built before continuing.'}
        </span>
        {isComplete ? null : (
          <button
            className="btn btn-primary"
            disabled={!gateOpen || continueMutation.isPending}
            onClick={() => continueMutation.mutate()}
            type="button"
          >
            {continueMutation.isPending ? 'Continuing...' : 'Continue to Manual Associations'}
          </button>
        )}
      </div>
      {continueMutation.isError ? (
        <div className="alert alert-error" role="alert">
          <span>{apiErrorMessage(continueMutation.error, 'Could not update the workflow stage.')}</span>
        </div>
      ) : null}
    </div>
  );
}
