import { fetchJson, HttpError } from '../lib/api.ts';
import { WORKFLOW_SNAPSHOT_KEY } from '@/queries.ts';
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

// A PI who can be given an appointment. projectCount leaves out 204 projects,
// which appointments never move.
export interface Pi {
  // Default OrgRs of the PI's non-204 projects.
  homeOrgRs: string[];
  name: string;
  projectCount: number;
  // The PI's 204 projects, which an appointment would leave in place.
  skipped204Count: number;
  ucpEmployeeId: string;
}

export interface PiAppointment {
  // Default OrgRs of the PI's non-204 projects.
  homeOrgRs: string[];
  name: string;
  orgR: string;
  // Projects the appointment places on orgR.
  projectCount: number;
  // 204 projects left on their default OrgR.
  skipped204Count: number;
  ucpEmployeeId: string;
}

export const ORGR_KEYS = {
  financialDepartments: ['orgr', 'financialDepartments'] as const,
  nifaDepartments: ['orgr', 'nifaDepartments'] as const,
  orgRs: ['orgr', 'list'] as const,
  piAppointments: ['orgr', 'piAppointments'] as const,
  pis: ['orgr', 'pis'] as const,
};

// Shared by OrgR edits and review completion so mapping edits and Continue block each other.
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

export const pisQueryOptions = () =>
  queryOptions({
    queryFn: () => fetchJson<Pi[]>('/api/orgr/pis'),
    queryKey: ORGR_KEYS.pis,
  });

export const piAppointmentsQueryOptions = () =>
  queryOptions({
    queryFn: () => fetchJson<PiAppointment[]>('/api/orgr/pi-appointments'),
    queryKey: ORGR_KEYS.piAppointments,
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
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: ORGR_KEYS.financialDepartments }),
        queryClient.invalidateQueries({ queryKey: ORGR_KEYS.orgRs }),
        queryClient.invalidateQueries({ queryKey: WORKFLOW_SNAPSHOT_KEY }),
      ]),
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
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: ORGR_KEYS.nifaDepartments }),
        queryClient.invalidateQueries({ queryKey: ORGR_KEYS.piAppointments }),
        queryClient.invalidateQueries({ queryKey: ORGR_KEYS.pis }),
        queryClient.invalidateQueries({ queryKey: ORGR_KEYS.orgRs }),
        queryClient.invalidateQueries({ queryKey: WORKFLOW_SNAPSHOT_KEY }),
      ]),
  });
};

// An appointment changes which projects sit on which OrgR, so the per OrgR
// project counts are refetched along with it.
function invalidatePiAppointments(queryClient: ReturnType<typeof useQueryClient>) {
  void queryClient.invalidateQueries({ queryKey: ORGR_KEYS.piAppointments });
  void queryClient.invalidateQueries({ queryKey: ORGR_KEYS.orgRs });
}

export const useAddPiAppointment = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { orgR: string; ucpEmployeeId: string }) =>
      fetchJson<void>('/api/orgr/pi-appointments', {
        body: JSON.stringify(input),
        method: 'POST',
      }),
    mutationKey: ORGR_MUTATION_KEY,
    onSettled: () => invalidatePiAppointments(queryClient),
  });
};

export const useRemovePiAppointment = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { orgR: string; ucpEmployeeId: string }) =>
      fetchJson<void>(
        `/api/orgr/pi-appointments/${encodeURIComponent(input.ucpEmployeeId)}/${encodeURIComponent(input.orgR)}`,
        { method: 'DELETE' }
      ),
    mutationKey: ORGR_MUTATION_KEY,
    onSettled: () => invalidatePiAppointments(queryClient),
  });
};
