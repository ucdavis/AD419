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
  | 'Activity'
  | 'Purpose'
  | 'Ern';

export interface HierarchyLevel {
  code: string;
  level: string;
  name: string | null;
}

export interface SegmentClassification {
  code: string;
  description: string | null;
  hierarchy: HierarchyLevel[];
  includeInReport: boolean | null;
  segmentType: SegmentType;
  sfn: string | null;
}

export interface SfnEntry {
  code: string;
  description: string;
}

// Mirrors the server's SfnCatalog (code and description stored separately).
export const SFN_CATALOG: SfnEntry[] = [
  { code: '201', description: 'Hatch Funds' },
  { code: '202', description: 'Multi-State Research Funds' },
  { code: '203', description: 'McIntire-Stennis Funds' },
  { code: '204', description: 'Contracts, Grants, Research Coop Agreements' },
  { code: '205', description: 'OtherFunds(AnimalHealthSec1433,Evans-Allen)' },
  { code: '209', description: 'National Science Foundation' },
  { code: '219', description: 'USDA Contracts, Grants, Coop Agreements' },
  { code: '220', description: 'State Appropriations' },
  { code: '221', description: 'Self-Generated Funds' },
  { code: '222', description: 'Industry Grants and Agreements' },
  { code: '223', description: 'Other Non-Federal Funds' },
];

export const FUND_SFNS = SFN_CATALOG.map((entry) => entry.code);
export const SFN_MULTIPLE = 'Multiple';

const SEGMENTS_KEY = ['segmentClassifications'] as const;

export const segmentClassificationsQueryOptions = () =>
  queryOptions({
    queryFn: () =>
      fetchJson<SegmentClassification[]>('/api/segmentclassifications'),
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
      fetchJson<void>('/api/segmentclassifications', {
        body: JSON.stringify(input),
        method: 'PATCH',
      }),
    onMutate: async (input) => {
      await queryClient.cancelQueries({ queryKey: SEGMENTS_KEY });
      const previous =
        queryClient.getQueryData<SegmentClassification[]>(SEGMENTS_KEY);

      queryClient.setQueryData<SegmentClassification[]>(SEGMENTS_KEY, (old) =>
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
