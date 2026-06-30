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
  onClassify: (segment: ChartStringSegment, include: boolean) => void;
  segments: ChartStringSegment[];
  segmentType: SegmentType;
}) {
  const columns: ColumnDef<ChartStringSegment>[] = [
    { accessorKey: 'code', header: 'Code' },
    { accessorKey: 'description', header: 'Name' },
    ...(segmentType === 'Fund'
      ? [{ accessorKey: 'sfn', header: 'SFN' } as ColumnDef<ChartStringSegment>]
      : []),
    {
      cell: ({ row }) => (
        <SegmentClassificationControl
          onClassify={(include) => onClassify(row.original, include)}
          segment={row.original}
        />
      ),
      header: 'Classification',
      id: 'classification',
    },
  ];

  return <DataTable columns={columns} data={segments} globalFilter="right" />;
}
