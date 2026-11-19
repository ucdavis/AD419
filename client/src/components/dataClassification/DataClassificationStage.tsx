import { useState } from 'react';
import {
  allClassified,
  SEGMENT_TABS,
  segmentsForType,
  unclassifiedCount,
} from './segments.ts';
import { buildSegmentExport } from './exportSegments.ts';
import { JobCodeTab } from './JobCodeTab.tsx';
import { SegmentGrid } from './SegmentGrid.tsx';
import { ExportDataButton } from '@/shared/exportDataButton.tsx';
import {
  ASSIGN_JOB_CODE_MUTATION_KEY,
  type AssignJobCodeInput,
  blockingJobCodeCount,
  jobCodeClassificationsQueryOptions,
  useAssignJobCode,
} from '@/queries/jobCodeClassifications.ts';
import { apiErrorMessage } from '@/queries/orgr.ts';
import {
  UPDATE_SEGMENT_CLASSIFICATION_MUTATION_KEY,
  segmentClassificationsQueryOptions,
  type SegmentClassification,
  type SegmentType,
  useUpdateSegmentClassification,
} from '@/queries/segmentClassifications.ts';
import {
  WORKFLOW_SNAPSHOT_KEY,
  updateWorkflowStageStatus,
} from '@/queries.ts';
import { useNavigate } from '@tanstack/react-router';
import {
  useIsMutating,
  useMutation,
  useMutationState,
  useQuery,
  useQueryClient,
} from '@tanstack/react-query';
import type { WorkflowStageStatus } from '@/types.ts';

// Job codes are classified to a job SFN through their own tab; they are not a
// chart-string segment, so they sit beside SEGMENT_TABS rather than in it.
const JOB_CODE_TAB = 'JobCode';
const JOB_CODE_NOTE =
  'The job SFN is the FTE line a job code reports on. Dollars are included either way. Without a line the FTE cannot be reported and State Appropriations (13U02) dollars cannot be auto-associated. Changes made after auto-associations have run apply when they are rebuilt.';

export function DataClassificationStage({
  status,
}: {
  status: WorkflowStageStatus;
}) {
  const { data: segments = [], isLoading } = useQuery(
    segmentClassificationsQueryOptions()
  );
  const jobCodesQuery = useQuery(jobCodeClassificationsQueryOptions());
  const updateClassification = useUpdateSegmentClassification();
  const assignJobCode = useAssignJobCode();
  const pendingSegmentUpdates = useIsMutating({
    mutationKey: UPDATE_SEGMENT_CLASSIFICATION_MUTATION_KEY,
  });
  const pendingJobCodeUpdates = useIsMutating({
    mutationKey: ASSIGN_JOB_CODE_MUTATION_KEY,
  });
  // Job codes with a save still running; their dropdowns are locked.
  const savingJobCodes = useMutationState({
    filters: { mutationKey: ASSIGN_JOB_CODE_MUTATION_KEY, status: 'pending' },
    select: (mutation) =>
      (mutation.state.variables as AssignJobCodeInput).jobCode,
  });
  const pendingClassificationUpdates =
    pendingSegmentUpdates + pendingJobCodeUpdates;
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const [activeType, setActiveType] = useState<
    SegmentType | typeof JOB_CODE_TAB
  >(SEGMENT_TABS[0].type);
  const continueMutation = useMutation({
    mutationFn: () =>
      updateWorkflowStageStatus('data-classification', 'Complete'),
    onSuccess: (snapshot) => {
      queryClient.setQueryData(WORKFLOW_SNAPSHOT_KEY, snapshot);
      void navigate({
        params: { stageId: 'expense-review' },
        to: '/workflow/$stageId',
      });
    },
  });

  if (isLoading) {
    return <p>Loading segments...</p>;
  }

  const handleClassify = (
    segment: SegmentClassification,
    includeInReport: boolean,
    sfn: string | null
  ) => {
    updateClassification.mutate({
      code: segment.code,
      includeInReport,
      segmentType: segment.segmentType,
      sfn,
    });
  };

  // Job codes that need a line block the stage like unclassified segments
  // do. Until they have loaded there is nothing to judge by, so the gate
  // stays closed, including when the request fails.
  const jobCodes = jobCodesQuery.data;
  const blockingJobCodes = jobCodes ? blockingJobCodeCount(jobCodes.rows) : 0;
  const jobCodesReady = jobCodes !== undefined && !jobCodesQuery.isError;
  const gateOpen =
    allClassified(segments) && jobCodesReady && blockingJobCodes === 0;
  const isComplete = status === 'Complete';
  const isJobCodeTab = activeType === JOB_CODE_TAB;
  const activeTab =
    SEGMENT_TABS.find((tab) => tab.type === activeType) ?? SEGMENT_TABS[0];
  const tabSegments = isJobCodeTab
    ? []
    : segmentsForType(segments, activeType);
  const exportData = buildSegmentExport(tabSegments, activeTab);
  const note = isJobCodeTab ? JOB_CODE_NOTE : activeTab.note;

  return (
    <div className="space-y-4">
      <p>
        New chart-string segments need to be classified before they can be
        included or excluded from the AD419 report.
      </p>

      {/* Shown on every tab: job codes gate Continue, so a failed load must
          not hide behind the Job Code tab. */}
      {jobCodesQuery.isError ? (
        <div className="alert alert-error" role="alert">
          <span>
            {apiErrorMessage(jobCodesQuery.error, 'Could not load job codes.')}
          </span>
        </div>
      ) : null}

      <div className="tabs tabs-bordered" role="tablist">
        {SEGMENT_TABS.map((tab) => {
          const count = unclassifiedCount(segments, tab.type);

          return (
            <button
              aria-selected={activeType === tab.type}
              className={`tab ${activeType === tab.type ? 'tab-active' : ''}`}
              key={tab.type}
              onClick={() => setActiveType(tab.type)}
              role="tab"
              type="button"
            >
              {tab.label}
              {count > 0 && (
                <span className="badge badge-warning badge-sm ml-2">
                  {count} new
                </span>
              )}
            </button>
          );
        })}
        <button
          aria-selected={isJobCodeTab}
          className={`tab ${isJobCodeTab ? 'tab-active' : ''}`}
          onClick={() => setActiveType(JOB_CODE_TAB)}
          role="tab"
          type="button"
        >
          Job Code
          {blockingJobCodes > 0 && (
            <span className="badge badge-warning badge-sm ml-2">
              {blockingJobCodes} new
            </span>
          )}
        </button>
      </div>

      {note && (
        <div className="alert alert-info" role="note">
          <span>{note}</span>
        </div>
      )}

      {isJobCodeTab ? (
        <>
          {assignJobCode.isError ? (
            <div className="alert alert-error" role="alert">
              <span>
                {apiErrorMessage(
                  assignJobCode.error,
                  'Could not save the job code.'
                )}
              </span>
            </div>
          ) : null}
          {jobCodesQuery.isError ? null : jobCodes ? (
            <JobCodeTab
              data={jobCodes}
              onAssign={(jobCode, staffTypeCode) =>
                assignJobCode.mutate({ jobCode, staffTypeCode })
              }
              savingJobCodes={savingJobCodes}
            />
          ) : (
            <p role="status">Loading job codes...</p>
          )}
        </>
      ) : (
        <SegmentGrid
          classificationHeader={activeTab.classificationHeader}
          onClassify={handleClassify}
          segments={tabSegments}
          segmentType={activeType}
          tableActions={
            <ExportDataButton
              columns={exportData.columns}
              data={exportData.rows}
              filename={exportData.filename}
              label="Export"
            />
          }
        />
      )}

      <div className="flex items-center justify-between border-t pt-4">
        <span className={gateOpen ? 'text-success' : 'text-warning'}>
          {gateOpen
            ? 'All segments classified.'
            : jobCodesQuery.isError
              ? 'Job codes could not be loaded.'
              : jobCodes === undefined
                ? 'Checking job codes...'
                : 'Unclassified rows must be set before the next step.'}
        </span>
        {isComplete ? null : gateOpen ? (
          <button
            className="btn btn-primary"
            disabled={
              continueMutation.isPending || pendingClassificationUpdates > 0
            }
            onClick={() => continueMutation.mutate()}
            type="button"
          >
            {continueMutation.isPending
              ? 'Continuing...'
              : 'Continue to Expense Review'}
          </button>
        ) : (
          <button className="btn btn-primary" disabled type="button">
            Continue to Expense Review
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
