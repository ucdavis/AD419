import { useState } from 'react';
import {
  allClassified,
  SEGMENT_TABS,
  segmentsForType,
  unclassifiedCount,
} from './segments.ts';
import { SegmentGrid } from './SegmentGrid.tsx';
import {
  chartStringSegmentsQueryOptions,
  type ChartStringSegment,
  useUpdateSegmentClassification,
} from '@/queries/chartStringSegments.ts';
import { Link } from '@tanstack/react-router';
import { useQuery } from '@tanstack/react-query';

export function DataClassificationStage() {
  const { data: segments = [], isLoading } = useQuery(
    chartStringSegmentsQueryOptions()
  );
  const updateClassification = useUpdateSegmentClassification();
  const [activeType, setActiveType] = useState(SEGMENT_TABS[0].type);

  if (isLoading) {
    return <p>Loading segments...</p>;
  }

  const handleClassify = (
    segment: ChartStringSegment,
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

      {activeType === 'Ern' && (
        <div className="alert alert-info" role="note">
          <span>
            Note: ERN (earnings) code classification affects FTE calculations only. It
            does not affect dollar-amount calculations.
          </span>
        </div>
      )}

      <SegmentGrid
        onClassify={handleClassify}
        segments={segmentsForType(segments, activeType)}
        segmentType={activeType}
      />

      <div className="flex items-center justify-between border-t pt-4">
        <span className={gateOpen ? 'text-success' : 'text-warning'}>
          {gateOpen
            ? 'All segments classified.'
            : 'Unclassified rows must be set before the next step.'}
        </span>
        {gateOpen ? (
          <Link
            className="btn btn-primary"
            params={{ stageId: 'expense-review' }}
            to="/workflow/$stageId"
          >
            Continue to Expense Review
          </Link>
        ) : (
          <button className="btn btn-primary" disabled type="button">
            Continue to Expense Review
          </button>
        )}
      </div>
    </div>
  );
}
