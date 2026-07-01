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
  const columns: ColumnDef<ChartStringSegment>[] = [
    { accessorKey: 'code', header: 'Code' },
    { accessorKey: 'description', header: 'Name' },
    {
      cell: ({ row }) => {
        const levels = row.original.hierarchy;
        if (levels.length === 0) {
          return <span className="text-base-content/40">—</span>;
        }
        return (
          <span className="flex flex-wrap items-center gap-1">
            {levels.map((level, index) => (
              <span className="inline-flex items-center gap-1" key={level.level}>
                {index > 0 && <span className="text-base-content/30">·</span>}
                <span
                  className="underline decoration-dotted cursor-help"
                  title={level.name ?? level.code}
                >
                  {level.code}
                </span>
              </span>
            ))}
          </span>
        );
      },
      header: 'Hierarchy',
      id: 'hierarchy',
    },
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

  return <DataTable columns={columns} data={segments} globalFilter="right" />;
}
