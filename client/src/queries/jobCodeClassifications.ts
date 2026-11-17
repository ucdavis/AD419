import { fetchJson } from '../lib/api.ts';
import { invalidateExpenseReviewQueries } from './expenseReview.ts';
import {
  queryOptions,
  useMutation,
  useQueryClient,
} from '@tanstack/react-query';

// One UCPath job code on payroll that is in the cycle and included in the
// report. fteSfn is the job SFN (FTE line), null while unassigned. A blocking
// code is unassigned and must be assigned before Data Classification can
// complete.
export interface JobCodeClassification {
  amount: number;
  blocking: boolean;
  employeeCount: number;
  fte: number;
  fteSfn: string | null;
  jobCode: string;
  staffTypeCode: string | null;
  titleName: string | null;
}

// A job code is assigned to a staff type; the staff type carries the line.
export interface StaffTypeOption {
  description: string | null;
  fteSfn: string;
  staffTypeCode: string;
}

export interface JobCodeClassifications {
  rows: JobCodeClassification[];
  staffTypes: StaffTypeOption[];
}

export interface AssignJobCodeInput {
  jobCode: string;
  staffTypeCode: string;
}

export const JOB_CODE_CLASSIFICATIONS_KEY = ['jobCodeClassifications'] as const;
export const ASSIGN_JOB_CODE_MUTATION_KEY = [
  'jobCodeClassifications',
  'assign',
] as const;

export const jobCodeClassificationsQueryOptions = () =>
  queryOptions({
    // The response also carries the cycle it was read for; the tab has no use for it.
    queryFn: () =>
      fetchJson<JobCodeClassifications>('/api/jobcodeclassifications').then(
        ({ rows, staffTypes }): JobCodeClassifications => ({ rows, staffTypes })
      ),
    queryKey: JOB_CODE_CLASSIFICATIONS_KEY,
  });

export function blockingJobCodeCount(rows: JobCodeClassification[]): number {
  return rows.filter((row) => row.blocking).length;
}

export const useAssignJobCode = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: AssignJobCodeInput) =>
      fetchJson<void>('/api/jobcodeclassifications', {
        body: JSON.stringify(input),
        method: 'PATCH',
      }),
    mutationKey: ASSIGN_JOB_CODE_MUTATION_KEY,
    onMutate: async (input) => {
      await queryClient.cancelQueries({ queryKey: JOB_CODE_CLASSIFICATIONS_KEY });
      const previous = queryClient.getQueryData<JobCodeClassifications>(
        JOB_CODE_CLASSIFICATIONS_KEY
      );

      queryClient.setQueryData<JobCodeClassifications>(
        JOB_CODE_CLASSIFICATIONS_KEY,
        (old) => {
          if (!old) {
            return old;
          }
          const option = old.staffTypes.find(
            (staffType) => staffType.staffTypeCode === input.staffTypeCode
          );
          return {
            ...old,
            rows: old.rows.map((row) =>
              row.jobCode === input.jobCode
                ? {
                    ...row,
                    blocking: false,
                    fteSfn: option?.fteSfn ?? row.fteSfn,
                    staffTypeCode: input.staffTypeCode,
                  }
                : row
            ),
          };
        }
      );

      return { previous };
    },
    // eslint-disable-next-line perfectionist/sort-objects
    onError: (_error, _input, context) => {
      if (context?.previous) {
        queryClient.setQueryData(JOB_CODE_CLASSIFICATIONS_KEY, context.previous);
      }
    },
    // The job SFN feeds the inclusion view that Expense Review reads.
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: JOB_CODE_CLASSIFICATIONS_KEY }),
        invalidateExpenseReviewQueries(queryClient),
      ]),
  });
};
