import type {
  AssociationRuleRow,
  ChecklistItem,
  ClassificationRow,
  DownloadFile,
  ExpenseTransactionRow,
  FilterTab,
  ProjectIssueRow,
  ReportRow,
  ReviewFlagRow,
  StaffTypeRow,
  StageMetric,
  WorkflowSnapshot,
  WorkflowStage,
  WorkflowStagePayload,
  WorkflowStageId,
} from './types.ts';

export const workflowStages: WorkflowStage[] = [
  {
    description:
      'Load the NIFA project list and resolve any data issues before pulling expenses.',
    id: 'project-identification',
    number: 1,
    status: 'complete',
    title: 'Project Identification',
  },
  {
    description:
      'Classify new chart-string segments before they can be included in the AD419 report.',
    id: 'data-classification',
    number: 2,
    status: 'complete',
    title: 'Data Classification',
  },
  {
    description:
      'Confirm the right transactions are included before triggering auto-associations.',
    id: 'expense-review',
    number: 3,
    status: 'in_progress',
    title: 'Expense Review',
  },
  {
    description:
      'Run the rules engine to associate as many expenses as possible before manual review.',
    id: 'auto-associations',
    number: 4,
    status: 'ready',
    title: 'Auto-Associations',
  },
  {
    description:
      'Resolve flagged items after manual associations are complete.',
    id: 'post-association-review',
    number: 5,
    status: 'locked',
    title: 'Post-Association Review',
  },
  {
    description:
      'Generate the final files for ANR submission and cycle signoff.',
    id: 'final-reports',
    number: 6,
    status: 'locked',
    title: 'Final Reports',
  },
];

export const workflowSnapshot: WorkflowSnapshot = {
  activity: {
    actor: 'Shannon',
    when: '12 min ago',
  },
  cycle: {
    label: 'FY:25',
    period: 'Oct 2024 - Sep 2025',
  },
  organization: 'CAES - ANR - BCBS',
  stages: workflowStages,
};

export const projectMetrics: StageMetric[] = [
  {
    detail: 'from active project list',
    label: 'Active NIFA projects',
    value: '366',
  },
  {
    detail: 'across all UC campuses',
    label: 'All NIFA projects',
    value: '1,842',
  },
  {
    detail: 'ae_dwh.pgm_master_data',
    label: 'PGM master records',
    value: '14,821',
  },
  {
    detail: 'federal listing',
    label: 'ALN / CFDA codes',
    value: '2,204',
  },
  {
    detail: 'see project list',
    label: 'Issues to resolve',
    value: '7',
  },
  {
    detail: '201 - 202 - 204 - 205',
    label: 'SFN distribution',
    value: '201 202 204 205',
  },
];

export const projectChecklist: ChecklistItem[] = [
  {
    detail: 'Set the reporting cycle',
    id: 'fiscal-period',
    status: 'complete',
    title: 'Confirm Fiscal Period',
  },
  {
    detail: 'ANR - all NIFA projects across UC campuses',
    id: 'all-projects',
    meta: '2,140 rows',
    status: 'complete',
    title: 'Upload All Projects List',
  },
  {
    detail: 'ANR - CAES projects required to report',
    id: 'active-projects',
    meta: '319 rows',
    status: 'complete',
    title: 'Upload Active Project List',
  },
  {
    detail: 'assistancelisting.usaspending.gov - updated weekly',
    id: 'cfda',
    meta: '2,291 rows',
    status: 'complete',
    title: 'Upload CFDA / ALN Data',
  },
  {
    detail: 'AE Redshift - ae_dwh.pgm_master_data',
    id: 'pgm-master',
    meta: '12,595 rows',
    status: 'complete',
    title: 'Import PGM Master Data',
  },
  {
    detail: 'Review flagged projects below',
    id: 'resolve-project-issues',
    meta: '7 issues',
    status: 'current',
    title: 'Resolve Project Issues',
  },
  {
    detail: 'Locks project data, triggers full expense pull',
    id: 'finalize-projects',
    status: 'pending',
    title: 'Finalize Projects',
  },
];

export const projectIssueRows: ProjectIssueRow[] = [
  {
    accession: '1053852',
    ae: '-',
    award: '-',
    id: 'issue-1',
    nifaProject: 'CA-B-WFC-2215-H',
    orgr: 'ATM',
    pi: 'Larkspur, S.',
    sfn: '201',
    status: '204 outside CAES',
  },
  {
    accession: '1055356',
    ae: '-',
    award: '-',
    id: 'issue-2',
    nifaProject: 'CA-SC-ARE-2981-H',
    orgr: 'ANS',
    pi: 'Okonkwo, Y.',
    sfn: '201',
    status: 'SFN mismatch',
  },
  {
    accession: '1078258',
    ae: '-',
    award: '-',
    id: 'issue-3',
    nifaProject: 'CA-I-ETX-2693-H',
    orgr: 'ETX',
    pi: 'Larkspur, S.',
    sfn: '201',
    status: 'No PGM match',
  },
  {
    accession: '1098295',
    ae: 'K2677',
    award: '2023-67365-48064',
    id: 'issue-4',
    nifaProject: 'CA-I-ADN-2345-CG',
    orgr: 'VEN',
    pi: 'Naidoo, T.',
    sfn: '204',
    status: '204 outside CAES',
  },
  {
    accession: '1045741',
    ae: 'K3265',
    award: '2022-69319-37497',
    id: 'issue-5',
    nifaProject: 'CA-D-MCB-2540-CG',
    orgr: 'ADN',
    pi: 'Pemberton, C.',
    sfn: '204',
    status: 'Expired project',
  },
  {
    accession: '1033084',
    ae: '-',
    award: '-',
    id: 'issue-6',
    nifaProject: 'CA-S-ARE-2621-RR',
    orgr: 'VEN',
    pi: 'O hAodha, K.',
    sfn: '202',
    status: 'Not in All Projects',
  },
  {
    accession: '1084023',
    ae: '-',
    award: '-',
    id: 'issue-7',
    nifaProject: 'CA-B-ENT-2091-AH',
    orgr: 'ASC',
    pi: 'Hahnemann, F.',
    sfn: '205',
    status: 'SFN mismatch',
  },
];

export const classificationTabs: FilterTab[] = [
  { count: '3 new', id: 'financial-dept', label: 'Financial Dept' },
  { count: '1 new', id: 'natural-account', label: 'Natural Account' },
  { count: '3 new', id: 'fund', label: 'Fund' },
  { count: '2 new', id: 'activity', label: 'Activity' },
];

export const classificationRows: ClassificationRow[] = [
  {
    code: '45530',
    hierarchy: ['State', 'AES', 'Operating', 'Unrestricted'],
    id: 'fund-45530',
    name: 'AES State Appropriations',
    sfn: '220',
  },
  {
    code: '95981',
    hierarchy: ['Federal', 'Formula', 'Hatch', 'Capacity'],
    id: 'fund-95981',
    name: 'USDA NIFA Hatch',
    sfn: '201',
  },
  {
    code: '38251',
    hierarchy: ['Federal', 'Formula', 'Regional', 'Capacity'],
    id: 'fund-38251',
    name: 'USDA NIFA Multistate',
    sfn: '202',
  },
  {
    code: '26088',
    hierarchy: ['Federal', 'Formula', 'AH', 'Capacity'],
    id: 'fund-26088',
    name: 'USDA NIFA Animal Health',
    sfn: '205',
  },
  {
    code: '42191',
    hierarchy: ['Federal', 'C&G', 'NSF', 'Restricted'],
    id: 'fund-42191',
    name: 'NSF Plant Genome Research',
    sfn: '209',
  },
  {
    code: '39773',
    hierarchy: ['Federal', 'C&G', 'USDA', 'Restricted'],
    id: 'fund-39773',
    name: 'USDA NIFA AFRI',
    sfn: '219',
  },
  {
    code: '46428',
    hierarchy: ['Endow.', 'Income', 'Restricted', '-'],
    id: 'fund-46428',
    name: 'Endowment Income - Restricted',
    sfn: 'Excluded',
  },
  {
    code: '70575',
    hierarchy: ['Federal', 'C&G', 'USDA', 'Restricted'],
    id: 'fund-70575',
    isNew: true,
    name: 'USDA NIFA SCRI Berry 2026',
    sfn: 'Unset',
  },
  {
    code: '61267',
    hierarchy: ['Federal', 'C&G', 'USDA', 'Restricted'],
    id: 'fund-61267',
    isNew: true,
    name: 'USDA NIFA OREI Cover Crops',
    sfn: 'Unset',
  },
  {
    code: '48360',
    hierarchy: ['Private', 'Industry', '-', 'Restricted'],
    id: 'fund-48360',
    isNew: true,
    name: 'Almond Board CA - 2026 Cycle',
    sfn: 'Unset',
  },
];

export const expenseMetrics: StageMetric[] = [
  { detail: 'Included transactions', label: 'Total included', value: '$70,122,954' },
  { detail: 'Salary FTE only', label: 'Total FTE', value: '389.2' },
];

export const expenseTabs: FilterTab[] = [
  { count: '413,802', id: 'all', label: 'All Transactions' },
  { count: '8', id: 'financial-dept', label: 'By Financial Dept' },
  { count: '8', id: 'sfn', label: 'By SFN' },
];

export const expenseTransactions: ExpenseTransactionRow[] = [
  {
    account: '415356',
    ae: '-',
    amount: '$36,273.93',
    department: '9AAES059A',
    employee: '-',
    fte: '-',
    fund: '20720',
    id: 'tx-1',
    nifaProject: 'CA-SC-FST-2737-AH',
    sfn: '201',
    source: 'AE',
  },
  {
    account: '501608',
    ae: '-',
    amount: '$63,975.82',
    department: '9AAES059A',
    employee: '-',
    fte: '-',
    fund: '20720',
    id: 'tx-2',
    nifaProject: 'CA-B-LAW-2710-H',
    sfn: '201',
    source: 'AE',
  },
  {
    account: '251775',
    ae: 'K3281',
    amount: '$27,939.03',
    department: 'VVME040',
    employee: '-',
    fte: '-',
    fund: '25510',
    id: 'tx-3',
    nifaProject: 'CA-D-BCB-2208-CG',
    sfn: '204',
    source: 'AE',
  },
  {
    account: '-',
    ae: '-',
    amount: '$15,728.69',
    department: '9AAES059A',
    employee: 'Whitfield, R.',
    fte: '0.06',
    fund: '20725',
    id: 'tx-4',
    nifaProject: 'CA-M-ARE-2643-AH',
    sfn: '202',
    source: 'UCP',
  },
  {
    account: '501608',
    ae: '-',
    amount: '$88,698.55',
    department: 'AAES689',
    employee: '-',
    fte: '-',
    fund: '20720',
    id: 'tx-5',
    nifaProject: 'CA-I-ANS-2175-RR',
    sfn: '201',
    source: 'AE',
  },
  {
    account: '-',
    ae: '-',
    amount: '$34,747.32',
    department: '9AAES059A',
    employee: 'Mehndiratta, R.',
    fte: '0.19',
    fund: '25510',
    id: 'tx-6',
    nifaProject: 'CA-D-PLS-2897-H',
    sfn: '204',
    source: 'UCP',
  },
  {
    account: '-',
    ae: 'K2677',
    amount: '$40,541.64',
    department: '9AAES583',
    employee: 'Dragan, S.',
    fte: '0.19',
    fund: '25510',
    id: 'tx-7',
    nifaProject: 'CA-I-ADN-2345-CG',
    sfn: '204',
    source: 'UCP',
  },
];

export const staffTypeRows: StaffTypeRow[] = [
  {
    code: '001512',
    expense: '$75,424',
    fte: '0.41',
    id: 'staff-1',
    title: 'PROJECT POLICY ANALYST 4 SUPERVISOR',
  },
  {
    code: '003466',
    expense: '$152,395',
    fte: '0.85',
    id: 'staff-2',
    title: 'RES & DEV ENGINEER 4',
  },
  {
    code: '004536',
    expense: '$175,375',
    fte: '0.73',
    id: 'staff-3',
    title: 'SPECIALIST IN AES SUPV 3',
  },
];

export const associationRuleRows: AssociationRuleRow[] = [
  {
    amount: '$21,797,541',
    id: 'rule-204',
    logic: 'Direct project match (locked)',
    rows: '6,075',
    share: '39%',
    status: 'Pending',
    type: '204',
  },
  {
    amount: '$10,074,114',
    id: 'rule-formula',
    logic: "Federal formula - prorated across PI's projects of same SFN",
    rows: '4,140',
    share: '18%',
    status: 'Pending',
    type: '201/202/205',
  },
  {
    amount: '$7,990,501',
    id: 'rule-state',
    logic: 'State 13U02 - prorated across all PI projects',
    rows: '2,725',
    share: '12%',
    status: 'Pending',
    type: '220',
  },
  {
    amount: '$1,209,746',
    id: 'rule-field-station',
    logic: 'Direct from Field Station import',
    rows: '589',
    share: '3%',
    status: 'Pending',
    type: 'Field Station',
  },
  {
    amount: '$701,588',
    id: 'rule-ce',
    logic: 'Direct from CES import',
    rows: '440',
    share: '2%',
    status: 'Pending',
    type: 'CE Specialist',
  },
];

export const postAssociationTabs: FilterTab[] = [
  { count: '4', id: 'under-100', label: 'Projects under $100' },
  { count: '3', id: 'fte', label: 'FTE > 1.0' },
  { count: '241', id: 'unassociated', label: 'Unassociated' },
  { count: '3', id: 'totals', label: 'Associated totals by SFN' },
];

export const reviewFlagRows: ReviewFlagRow[] = [
  {
    id: 'review-1',
    pi: 'Brockmann, S.',
    project: 'CA-I-ADN-2966-CG',
    total: '$47.47',
  },
  {
    id: 'review-2',
    pi: 'Brockmann, G.',
    project: 'CA-SC-NUT-2088-RR',
    total: '$29.75',
  },
  {
    id: 'review-3',
    pi: 'Voronova, S.',
    project: 'CA-D-PLS-2154-AH',
    total: '$2.24',
  },
  {
    id: 'review-4',
    pi: 'Voskuilen, W.',
    project: 'CA-I-FST-2046-CG',
    total: '$18.56',
  },
];

export const reportRows: ReportRow[] = [
  {
    accession: '1082759',
    fte: '1.2',
    id: 'report-1',
    pi: 'Calderon, T.',
    project: 'CA-B-BCB-2179-RR',
    sfn201: '-',
    sfn202: '$89,125',
    sfn204: '-',
    sfn205: '-',
    sfn209: '$27,027',
    sfn219: '-',
    sfn220: '$38,985',
    sfn22f: '-',
  },
  {
    accession: '1057723',
    fte: '0.8',
    id: 'report-2',
    pi: 'Lindqvist, F.',
    project: 'CA-D-ENT-2326-CG',
    sfn201: '-',
    sfn202: '-',
    sfn204: '$147,763',
    sfn205: '-',
    sfn209: '-',
    sfn219: '-',
    sfn220: '$185,716',
    sfn22f: '-',
  },
  {
    accession: '1019007',
    fte: '1.6',
    id: 'report-3',
    pi: 'Trent, S.',
    project: 'CA-SC-VME-2901-AH',
    sfn201: '-',
    sfn202: '-',
    sfn204: '-',
    sfn205: '$221,553',
    sfn209: '-',
    sfn219: '$41,538',
    sfn220: '$27,763',
    sfn22f: '-',
  },
  {
    accession: '1093399',
    fte: '0.7',
    id: 'report-4',
    pi: 'Aparicio, D.',
    project: 'CA-S-ETX-2906-H',
    sfn201: '$125,664',
    sfn202: '-',
    sfn204: '-',
    sfn205: '-',
    sfn209: '$15,018',
    sfn219: '-',
    sfn220: '$136,425',
    sfn22f: '-',
  },
  {
    accession: '1049563',
    fte: '2.5',
    id: 'report-5',
    pi: 'Vasquez, D.',
    project: 'CA-SC-NUT-2919-AH',
    sfn201: '-',
    sfn202: '-',
    sfn204: '-',
    sfn205: '$163,936',
    sfn209: '-',
    sfn219: '-',
    sfn220: '$94,350',
    sfn22f: '-',
  },
];

export const downloadFiles: DownloadFile[] = [
  {
    detail: 'Full SFN breakdown - 366 rows',
    fileName: 'AD419-Admin.csv',
    id: 'admin',
  },
  {
    detail: 'Simplified format - 366 rows',
    fileName: 'AD419-NonAdmin.csv',
    id: 'non-admin',
  },
  {
    detail: 'FTE by SFN - 366 rows',
    fileName: 'AD419-FTE.csv',
    id: 'fte',
  },
  {
    detail: 'ANR submission cover - totals + signoff',
    fileName: 'AD419-Summary.xlsx',
    id: 'summary',
  },
];

export const workflowStagePayloads: Record<
  WorkflowStageId,
  WorkflowStagePayload
> = {
  'auto-associations': {
    rules: associationRuleRows,
    staffTypes: staffTypeRows,
    stageId: 'auto-associations',
  },
  'data-classification': {
    rows: classificationRows,
    stageId: 'data-classification',
    tabs: classificationTabs,
  },
  'expense-review': {
    metrics: expenseMetrics,
    rows: expenseTransactions,
    stageId: 'expense-review',
    tabs: expenseTabs,
  },
  'final-reports': {
    downloads: downloadFiles,
    rows: reportRows,
    stageId: 'final-reports',
    tabs: [
      { id: 'admin', label: 'Admin (full breakdown)' },
      { id: 'non-admin', label: 'Non-Admin (simplified)' },
    ],
  },
  'post-association-review': {
    rows: reviewFlagRows,
    stageId: 'post-association-review',
    tabs: postAssociationTabs,
  },
  'project-identification': {
    checklist: projectChecklist,
    issues: projectIssueRows,
    metrics: projectMetrics,
    stageId: 'project-identification',
  },
};

export const workflowStageIds = workflowStages.map((stage) => stage.id);

export function findWorkflowStage(stageId: string): WorkflowStage | undefined {
  return workflowStages.find((stage) => stage.id === stageId);
}

export function findWorkflowStageDetails(
  stageId: WorkflowStageId
): { payload: WorkflowStagePayload; stage: WorkflowStage } | undefined {
  const stage = findWorkflowStage(stageId);

  if (!stage) {
    return undefined;
  }

  return {
    payload: workflowStagePayloads[stageId],
    stage,
  };
}

export function getCurrentAvailableStageId(
  snapshot: WorkflowSnapshot
): WorkflowStageId {
  return (
    snapshot.stages.find((stage) => stage.status === 'in_progress') ??
    snapshot.stages.find((stage) => stage.status === 'ready') ??
    snapshot.stages.find((stage) => stage.status !== 'locked') ??
    snapshot.stages[0]
  ).id;
}

export function canAccessStage(stageId: string): stageId is WorkflowStageId {
  const stage = findWorkflowStage(stageId);
  return Boolean(stage && stage.status !== 'locked');
}
