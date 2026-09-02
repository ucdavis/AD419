import { fetchJson, HttpError } from '../lib/api.ts';
import {
  queryOptions,
  useMutation,
  useQueryClient,
} from '@tanstack/react-query';
import type { HierarchyLevel } from '@/queries/segmentClassifications.ts';

export interface OrgR {
  code: string;
  financialDepartmentCount: number;
  nifaProjectCount: number;
  // Every mapping row pointing at the OrgR; gates deletion.
  referenceCount: number;
}

export interface OrgRFinancialDepartment {
  description: string | null;
  financialDepartment: string;
  hierarchy: HierarchyLevel[];
  orgR: string | null;
}

export interface OrgRNifaDepartment {
  nifaDepartment: string;
  orgR: string | null;
  projectCount: number;
}

export interface ProjectOrgR {
  accessionNumber: string;
  nifaProjectNumber: string;
  orgR: string;
  projectDirector: string | null;
  source: 'Default' | 'Manual';
  title: string | null;
}

export const ORGR_KEYS = {
  financialDepartments: ['orgr', 'financialDepartments'] as const,
  nifaDepartments: ['orgr', 'nifaDepartments'] as const,
  orgRs: ['orgr', 'list'] as const,
  projects: ['orgr', 'projects'] as const,
};

// Shared by every OrgR mutation so the stage can block Continue while saving.
export const ORGR_MUTATION_KEY = ['orgr', 'mutate'] as const;

export const orgRsQueryOptions = () =>
  queryOptions({
    queryFn: () => fetchJson<OrgR[]>('/api/orgr/orgrs'),
    queryKey: ORGR_KEYS.orgRs,
  });

export const orgRFinancialDepartmentsQueryOptions = () =>
  queryOptions({
    queryFn: () =>
      fetchJson<OrgRFinancialDepartment[]>('/api/orgr/financial-departments'),
    queryKey: ORGR_KEYS.financialDepartments,
  });

export const orgRNifaDepartmentsQueryOptions = () =>
  queryOptions({
    queryFn: () =>
      fetchJson<OrgRNifaDepartment[]>('/api/orgr/nifa-departments'),
    queryKey: ORGR_KEYS.nifaDepartments,
  });

export const projectOrgRsQueryOptions = () =>
  queryOptions({
    queryFn: () => fetchJson<ProjectOrgR[]>('/api/orgr/projects'),
    queryKey: ORGR_KEYS.projects,
  });

export function apiErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof HttpError && typeof error.body === 'string' && error.body) {
    return error.body;
  }
  return error instanceof Error ? error.message : fallback;
}

export const useCreateOrgR = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (code: string) =>
      fetchJson<void>(`/api/orgr/orgrs/${encodeURIComponent(code)}`, {
        method: 'PUT',
      }),
    mutationKey: ORGR_MUTATION_KEY,
    onSettled: () => queryClient.invalidateQueries({ queryKey: ORGR_KEYS.orgRs }),
  });
};

export const useDeleteOrgR = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (code: string) =>
      fetchJson<void>(`/api/orgr/orgrs/${encodeURIComponent(code)}`, {
        method: 'DELETE',
      }),
    mutationKey: ORGR_MUTATION_KEY,
    onSettled: () => queryClient.invalidateQueries({ queryKey: ORGR_KEYS.orgRs }),
  });
};

export const useSetFinancialDepartmentOrgR = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { financialDepartment: string; orgR: string | null }) =>
      fetchJson<void>(
        `/api/orgr/financial-departments/${encodeURIComponent(input.financialDepartment)}`,
        { body: JSON.stringify({ orgR: input.orgR }), method: 'PATCH' }
      ),
    mutationKey: ORGR_MUTATION_KEY,
    onMutate: async (input) => {
      await queryClient.cancelQueries({ queryKey: ORGR_KEYS.financialDepartments });
      const previous = queryClient.getQueryData<OrgRFinancialDepartment[]>(
        ORGR_KEYS.financialDepartments
      );
      queryClient.setQueryData<OrgRFinancialDepartment[]>(
        ORGR_KEYS.financialDepartments,
        (old) =>
          (old ?? []).map((row) =>
            row.financialDepartment === input.financialDepartment
              ? { ...row, orgR: input.orgR }
              : row
          )
      );
      return { previous };
    },
    // eslint-disable-next-line perfectionist/sort-objects
    onError: (_error, _input, context) => {
      if (context?.previous) {
        queryClient.setQueryData(ORGR_KEYS.financialDepartments, context.previous);
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ORGR_KEYS.financialDepartments });
      void queryClient.invalidateQueries({ queryKey: ORGR_KEYS.orgRs });
    },
  });
};

export const useSetNifaDepartmentOrgR = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { nifaDepartment: string; orgR: string | null }) =>
      fetchJson<void>(
        `/api/orgr/nifa-departments/${encodeURIComponent(input.nifaDepartment)}`,
        { body: JSON.stringify({ orgR: input.orgR }), method: 'PATCH' }
      ),
    mutationKey: ORGR_MUTATION_KEY,
    onMutate: async (input) => {
      await queryClient.cancelQueries({ queryKey: ORGR_KEYS.nifaDepartments });
      const previous = queryClient.getQueryData<OrgRNifaDepartment[]>(
        ORGR_KEYS.nifaDepartments
      );
      queryClient.setQueryData<OrgRNifaDepartment[]>(
        ORGR_KEYS.nifaDepartments,
        (old) =>
          (old ?? []).map((row) =>
            row.nifaDepartment === input.nifaDepartment
              ? { ...row, orgR: input.orgR }
              : row
          )
      );
      return { previous };
    },
    // eslint-disable-next-line perfectionist/sort-objects
    onError: (_error, _input, context) => {
      if (context?.previous) {
        queryClient.setQueryData(ORGR_KEYS.nifaDepartments, context.previous);
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ORGR_KEYS.nifaDepartments });
      void queryClient.invalidateQueries({ queryKey: ORGR_KEYS.projects });
      void queryClient.invalidateQueries({ queryKey: ORGR_KEYS.orgRs });
    },
  });
};

export const useAddProjectOrgR = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { accessionNumber: string; orgR: string }) =>
      fetchJson<void>('/api/orgr/projects', {
        body: JSON.stringify(input),
        method: 'POST',
      }),
    mutationKey: ORGR_MUTATION_KEY,
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ORGR_KEYS.projects });
      void queryClient.invalidateQueries({ queryKey: ORGR_KEYS.orgRs });
    },
  });
};

export const useRemoveProjectOrgR = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { accessionNumber: string; orgR: string }) =>
      fetchJson<void>(
        `/api/orgr/projects/${encodeURIComponent(input.accessionNumber)}/${encodeURIComponent(input.orgR)}`,
        { method: 'DELETE' }
      ),
    mutationKey: ORGR_MUTATION_KEY,
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ORGR_KEYS.projects });
      void queryClient.invalidateQueries({ queryKey: ORGR_KEYS.orgRs });
    },
  });
};
