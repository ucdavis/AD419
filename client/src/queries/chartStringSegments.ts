import { fetchJson } from '../lib/api.ts';
import {
  queryOptions,
  useMutation,
  useQueryClient,
} from '@tanstack/react-query';

export type SegmentType =
  | 'FinancialDepartment'
  | 'Account'
  | 'Fund'
  | 'Activity';

export interface HierarchyLevel {
  code: string;
  level: string;
  name: string | null;
}

export interface ChartStringSegment {
  code: string;
  description: string | null;
  hierarchy: HierarchyLevel[];
  includeInReport: boolean | null;
  segmentType: SegmentType;
  sfn: string | null;
}

export const FUND_SFNS = ['201', '202', '203', '205', '220', '221', '223'] as const;
export const SFN_MULTIPLE = 'Multiple';

const SEGMENTS_KEY = ['chartStringSegments'] as const;

export const chartStringSegmentsQueryOptions = () =>
  queryOptions({
    queryFn: () =>
      fetchJson<ChartStringSegment[]>('/api/chartstringsegments'),
    queryKey: SEGMENTS_KEY,
  });

export interface UpdateClassificationInput {
  code: string;
  includeInReport: boolean;
  segmentType: SegmentType;
  sfn: string | null;
}

export const useUpdateSegmentClassification = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: UpdateClassificationInput) =>
      fetchJson<void>('/api/chartstringsegments', {
        body: JSON.stringify(input),
        method: 'PATCH',
      }),
    onMutate: async (input) => {
      await queryClient.cancelQueries({ queryKey: SEGMENTS_KEY });
      const previous =
        queryClient.getQueryData<ChartStringSegment[]>(SEGMENTS_KEY);

      queryClient.setQueryData<ChartStringSegment[]>(SEGMENTS_KEY, (old) =>
        (old ?? []).map((segment) =>
          segment.segmentType === input.segmentType &&
          segment.code === input.code
            ? { ...segment, includeInReport: input.includeInReport, sfn: input.sfn }
            : segment
        )
      );

      return { previous };
    },
    // eslint-disable-next-line perfectionist/sort-objects
    onError: (_error, _input, context) => {
      if (context?.previous) {
        queryClient.setQueryData(SEGMENTS_KEY, context.previous);
      }
    },
    onSettled: () =>
      queryClient.invalidateQueries({ queryKey: SEGMENTS_KEY }),
  });
};
