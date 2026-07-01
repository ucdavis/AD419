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
