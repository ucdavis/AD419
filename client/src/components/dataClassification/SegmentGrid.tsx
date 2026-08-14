import { useState, type ReactNode } from 'react';
import { SegmentClassificationControl } from './SegmentClassificationControl.tsx';
import type {
  SegmentClassification,
  SegmentType,
} from '@/queries/segmentClassifications.ts';
import { DataTable } from '@/shared/dataTable.tsx';
import type { ColumnDef } from '@tanstack/react-table';

function classificationSortValue(segment: SegmentClassification): string {
  if (segment.includeInReport === null) {
    return '';
  }
  return segment.includeInReport ? (segment.sfn ?? 'Included') : 'Excluded';
}

// Codes ordered with unclassified (unset) rows first, otherwise stable.
function unsetFirstCodes(segments: SegmentClassification[]): string[] {
  return [...segments]
    .sort(
      (a, b) =>
        (a.includeInReport === null ? 0 : 1) -
        (b.includeInReport === null ? 0 : 1)
    )
    .map((segment) => segment.code);
}

export function SegmentGrid({
  classificationHeader,
  onClassify,
  segments,
  segmentType,
  tableActions,
}: {
  classificationHeader: string;
  onClassify: (
    segment: SegmentClassification,
    includeInReport: boolean,
    sfn: string | null
  ) => void;
  segments: SegmentClassification[];
  segmentType: SegmentType;
  tableActions?: ReactNode;
}) {
  const levelKeys =
    segmentType === 'Purpose'
      ? []
      : [
          ...new Set(
            segments.flatMap((segment) =>
              segment.hierarchy.map((level) => level.level)
            )
          ),
        ].sort();

  const levelColumns: ColumnDef<SegmentClassification>[] = levelKeys.map(
    (levelKey) => ({
      accessorFn: (segment) =>
        segment.hierarchy.find((level) => level.level === levelKey)?.code ?? '',
      cell: ({ row }) => {
        const level = row.original.hierarchy.find(
          (candidate) => candidate.level === levelKey
        );
        if (!level) {
          return <span className="text-base-content/40">—</span>;
        }
        return (
          <span
            className="tooltip tooltip-right underline decoration-dotted cursor-help"
            data-tip={level.name ?? level.code}
          >
            {level.code}
          </span>
        );
      },
      header: `Level ${levelKey}`,
      id: `level-${levelKey}`,
    })
  );

  const columns: ColumnDef<SegmentClassification>[] = [
    { accessorKey: 'code', header: 'Code' },
    { accessorKey: 'description', header: 'Name' },
    ...levelColumns,
    {
      accessorFn: classificationSortValue,
      cell: ({ row }) => (
        <SegmentClassificationControl
          onClassify={(includeInReport, sfn) =>
            onClassify(row.original, includeInReport, sfn)
          }
          segment={row.original}
        />
      ),
      header: classificationHeader,
      id: 'classification',
    },
  ];

  // Freeze the default row order when the tab is entered: unclassified rows on top,
  // otherwise stable. Recomputed only when the segment type changes (the "adjust
  // state when a prop changes" pattern), so classifying a row in place does not
  // immediately move it. Column sorting (below) overrides this when a header is
  // clicked.
  const [order, setOrder] = useState<{ codes: string[]; type: SegmentType }>(
    () => ({ codes: unsetFirstCodes(segments), type: segmentType })
  );
  if (order.type !== segmentType) {
    setOrder({ codes: unsetFirstCodes(segments), type: segmentType });
  }
  const orderIndex = new Map(order.codes.map((code, index) => [code, index]));
  const orderedSegments = [...segments].sort(
    (a, b) => (orderIndex.get(a.code) ?? 0) - (orderIndex.get(b.code) ?? 0)
  );

  return (
    <DataTable
      columns={columns}
      data={orderedSegments}
      globalFilter="right"
      initialState={{ pagination: { pageSize: 25 } }}
      key={segmentType}
      tableActions={tableActions}
    />
  );
}
