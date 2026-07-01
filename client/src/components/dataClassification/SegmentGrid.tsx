import { SegmentClassificationControl } from './SegmentClassificationControl.tsx';
import type {
  ChartStringSegment,
  SegmentType,
} from '@/queries/chartStringSegments.ts';
import { DataTable } from '@/shared/dataTable.tsx';
import type { ColumnDef } from '@tanstack/react-table';

export function SegmentGrid({
  onClassify,
  segments,
  segmentType,
}: {
  onClassify: (
    segment: ChartStringSegment,
    includeInReport: boolean,
    sfn: string | null
  ) => void;
  segments: ChartStringSegment[];
  segmentType: SegmentType;
}) {
  const levelKeys = [
    ...new Set(
      segments.flatMap((segment) =>
        segment.hierarchy.map((level) => level.level)
      )
    ),
  ].sort();

  const levelColumns: ColumnDef<ChartStringSegment>[] = levelKeys.map(
    (levelKey) => ({
      cell: ({ row }) => {
        const level = row.original.hierarchy.find(
          (candidate) => candidate.level === levelKey
        );
        if (!level) {
          return <span className="text-base-content/40">—</span>;
        }
        return (
          <span
            className="underline decoration-dotted cursor-help"
            title={level.name ?? level.code}
          >
            {level.code}
          </span>
        );
      },
      header: `Level ${levelKey}`,
      id: `level-${levelKey}`,
    })
  );

  const columns: ColumnDef<ChartStringSegment>[] = [
    { accessorKey: 'code', header: 'Code' },
    { accessorKey: 'description', header: 'Name' },
    ...levelColumns,
    {
      cell: ({ row }) => (
        <SegmentClassificationControl
          onClassify={(includeInReport, sfn) =>
            onClassify(row.original, includeInReport, sfn)
          }
          segment={row.original}
        />
      ),
      header: 'Classification',
      id: 'classification',
    },
  ];

  // Unclassified (unset) rows sort to the top; order is otherwise stable.
  const orderedSegments = [...segments].sort(
    (a, b) =>
      (a.includeInReport === null ? 0 : 1) -
      (b.includeInReport === null ? 0 : 1)
  );

  return (
    <DataTable
      columns={columns}
      data={orderedSegments}
      globalFilter="right"
      initialState={{ pagination: { pageSize: 25 } }}
    />
  );
}
