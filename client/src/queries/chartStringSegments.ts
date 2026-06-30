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

export interface ChartStringSegment {
  code: string;
  description: string | null;
  includeInReport: boolean | null;
  segmentType: SegmentType;
  sfn: string | null;
}

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
            ? { ...segment, includeInReport: input.includeInReport }
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
