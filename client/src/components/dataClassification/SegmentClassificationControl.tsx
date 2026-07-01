import {
  FUND_SFNS,
  SFN_MULTIPLE,
  type ChartStringSegment,
} from '@/queries/chartStringSegments.ts';

const EXCLUDED = 'Excluded';

export function SegmentClassificationControl({
  onClassify,
  segment,
}: {
  onClassify: (includeInReport: boolean, sfn: string | null) => void;
  segment: ChartStringSegment;
}) {
  if (segment.segmentType === 'Fund') {
    const value =
      segment.includeInReport === false
        ? EXCLUDED
        : (segment.sfn ?? '');

    const handleChange = (selected: string) => {
      if (selected === EXCLUDED) {
        onClassify(false, null);
      } else if (selected !== '') {
        onClassify(true, selected);
      }
    };

    return (
      <select
        className="select select-xs select-bordered"
        onChange={(event) => handleChange(event.target.value)}
        value={value}
      >
        <option disabled value="">
          Unset
        </option>
        {FUND_SFNS.map((sfn) => (
          <option key={sfn} value={sfn}>
            {sfn}
          </option>
        ))}
        <option value={SFN_MULTIPLE}>Multiple</option>
        <option value={EXCLUDED}>Excluded</option>
      </select>
    );
  }

  const status = segment.includeInReport;

  return (
    <div className="flex items-center gap-2">
      <button
        className={`btn btn-xs ${status === true ? 'btn-success' : 'btn-ghost'}`}
        onClick={() => onClassify(true, null)}
        type="button"
      >
        Include
      </button>
      <button
        className={`btn btn-xs ${status === false ? 'btn-error' : 'btn-ghost'}`}
        onClick={() => onClassify(false, null)}
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
