import type { ChartStringSegment } from '@/queries/chartStringSegments.ts';

export function SegmentClassificationControl({
  onClassify,
  segment,
}: {
  onClassify: (include: boolean) => void;
  segment: ChartStringSegment;
}) {
  const status = segment.includeInReport;

  return (
    <div className="flex items-center gap-2">
      <button
        className={`btn btn-xs ${status === true ? 'btn-success' : 'btn-ghost'}`}
        onClick={() => onClassify(true)}
        type="button"
      >
        Include
      </button>
      <button
        className={`btn btn-xs ${status === false ? 'btn-error' : 'btn-ghost'}`}
        onClick={() => onClassify(false)}
        type="button"
      >
        Exclude
      </button>
      {status === null && (
        <span className="badge badge-warning badge-sm">Unset</span>
      )}
    </div>
  );
}
