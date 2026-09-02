import { useState } from 'react';
import { allMapped, ORGR_TABS, type OrgRTabId, unmappedCount } from './orgrTabs.ts';
import { FinancialDepartmentsTab } from './FinancialDepartmentsTab.tsx';
import { NifaDepartmentsTab } from './NifaDepartmentsTab.tsx';
import { OrgRListTab } from './OrgRListTab.tsx';
import { ProjectOrgRsTab } from './ProjectOrgRsTab.tsx';
import {
  apiErrorMessage,
  ORGR_MUTATION_KEY,
  orgRFinancialDepartmentsQueryOptions,
  orgRNifaDepartmentsQueryOptions,
} from '@/queries/orgr.ts';
import { WORKFLOW_SNAPSHOT_KEY, updateWorkflowStageStatus } from '@/queries.ts';
import type { WorkflowStageStatus } from '@/types.ts';
import { useNavigate } from '@tanstack/react-router';
import {
  useIsMutating,
  useMutation,
  useQuery,
  useQueryClient,
} from '@tanstack/react-query';

export function OrgRReviewStage({ status }: { status: WorkflowStageStatus }) {
  const {
    data: departments = [],
    error: departmentsError,
    isError: departmentsIsError,
    isLoading: departmentsLoading,
  } = useQuery(orgRFinancialDepartmentsQueryOptions());
  const {
    data: nifaDepartments = [],
    error: nifaError,
    isError: nifaIsError,
    isLoading: nifaLoading,
  } = useQuery(orgRNifaDepartmentsQueryOptions());
  const pendingMutations = useIsMutating({ mutationKey: ORGR_MUTATION_KEY });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const [activeId, setActiveId] = useState<OrgRTabId>(ORGR_TABS[0].id);
  const continueMutation = useMutation({
    mutationFn: () => updateWorkflowStageStatus('orgr-review', 'Complete'),
    onSuccess: (snapshot) => {
      queryClient.setQueryData(WORKFLOW_SNAPSHOT_KEY, snapshot);
      void navigate({
        params: { stageId: 'auto-associations' },
        to: '/workflow/$stageId',
      });
    },
  });

  if (departmentsLoading || nifaLoading) {
    return <p>Loading OrgR mappings...</p>;
  }

  const hasLoadError = departmentsIsError || nifaIsError;
  const gateOpen = !hasLoadError && allMapped(departments, nifaDepartments);
  const isComplete = status === 'Complete';
  const activeTab = ORGR_TABS.find((tab) => tab.id === activeId) ?? ORGR_TABS[0];
  const badgeFor = (id: OrgRTabId): number =>
    hasLoadError
      ? 0
      : id === 'financial-departments'
        ? unmappedCount(departments)
        : id === 'nifa-departments'
          ? unmappedCount(nifaDepartments)
          : 0;

  return (
    <div className="space-y-4">
      <p>
        OrgR drives proration and screen grouping in the associations step, so
        every included financial department and NIFA department needs one before
        continuing.
      </p>

      {hasLoadError ? (
        <div className="alert alert-error" role="alert">
          <span>
            {apiErrorMessage(
              departmentsError ?? nifaError,
              'Could not load OrgR mappings.'
            )}
          </span>
        </div>
      ) : null}

      <div className="tabs tabs-bordered" role="tablist">
        {ORGR_TABS.map((tab) => {
          const count = badgeFor(tab.id);
          return (
            <button
              aria-selected={activeId === tab.id}
              className={`tab ${activeId === tab.id ? 'tab-active' : ''}`}
              key={tab.id}
              onClick={() => setActiveId(tab.id)}
              role="tab"
              type="button"
            >
              {tab.label}
              {count > 0 && (
                <span className="badge badge-warning badge-sm ml-2">
                  {count} needs review
                </span>
              )}
            </button>
          );
        })}
      </div>

      {activeTab.note && (
        <div className="alert alert-info" role="note">
          <span>{activeTab.note}</span>
        </div>
      )}

      {activeId === 'orgrs' ? (
        <OrgRListTab />
      ) : activeId === 'financial-departments' ? (
        <FinancialDepartmentsTab />
      ) : activeId === 'nifa-departments' ? (
        <NifaDepartmentsTab />
      ) : (
        <ProjectOrgRsTab />
      )}

      <div className="flex items-center justify-between border-t pt-4">
        <span className={gateOpen ? 'text-success' : 'text-warning'}>
          {hasLoadError
            ? 'OrgR mappings could not be loaded.'
            : gateOpen
              ? 'All departments have an OrgR.'
              : 'Every financial department and NIFA department needs an OrgR before the next step.'}
        </span>
        {isComplete ? null : (
          <button
            className="btn btn-primary"
            disabled={!gateOpen || continueMutation.isPending || pendingMutations > 0}
            onClick={() => continueMutation.mutate()}
            type="button"
          >
            {continueMutation.isPending ? 'Continuing...' : 'Continue to Auto-Associations'}
          </button>
        )}
      </div>
      {continueMutation.isError ? (
        <div className="alert alert-error" role="alert">
          <span>
            {continueMutation.error instanceof Error
              ? continueMutation.error.message
              : 'Could not update the workflow stage.'}
          </span>
        </div>
      ) : null}
    </div>
  );
}
