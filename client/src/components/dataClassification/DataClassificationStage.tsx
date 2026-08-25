import { useState } from 'react';
import {
  allClassified,
  SEGMENT_TABS,
  segmentsForType,
  unclassifiedCount,
} from './segments.ts';
import { buildSegmentExport } from './exportSegments.ts';
import { SegmentGrid } from './SegmentGrid.tsx';
import { ExportDataButton } from '@/shared/exportDataButton.tsx';
import {
  UPDATE_SEGMENT_CLASSIFICATION_MUTATION_KEY,
  segmentClassificationsQueryOptions,
  type SegmentClassification,
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
  useQuery,
  useQueryClient,
} from '@tanstack/react-query';
import type { WorkflowStageStatus } from '@/types.ts';

export function DataClassificationStage({
  status,
}: {
  status: WorkflowStageStatus;
}) {
  const { data: segments = [], isLoading } = useQuery(
    segmentClassificationsQueryOptions()
  );
  const updateClassification = useUpdateSegmentClassification();
  const pendingClassificationUpdates = useIsMutating({
    mutationKey: UPDATE_SEGMENT_CLASSIFICATION_MUTATION_KEY,
  });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const [activeType, setActiveType] = useState(SEGMENT_TABS[0].type);
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

  const gateOpen = allClassified(segments);
  const isComplete = status === 'Complete';
  const activeTab =
    SEGMENT_TABS.find((tab) => tab.type === activeType) ?? SEGMENT_TABS[0];
  const tabSegments = segmentsForType(segments, activeType);
  const exportData = buildSegmentExport(tabSegments, activeTab);

  return (
    <div className="space-y-4">
      <p>
        New chart-string segments need to be classified before they can be
        included or excluded from the AD419 report.
      </p>

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
      </div>

      {activeTab.note && (
        <div className="alert alert-info" role="note">
          <span>{activeTab.note}</span>
        </div>
      )}

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

      <div className="flex items-center justify-between border-t pt-4">
        <span className={gateOpen ? 'text-success' : 'text-warning'}>
          {gateOpen
            ? 'All segments classified.'
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
