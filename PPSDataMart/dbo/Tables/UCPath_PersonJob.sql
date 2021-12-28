CREATE TABLE [dbo].[UCPath_PersonJob] (
    [NAME]                   NVARCHAR (50)   NOT NULL,
    [LAST_NAME]              NVARCHAR (30)   NULL,
    [FIRST_NAME]             NVARCHAR (30)   NULL,
    [MIDDLE_NAME]            NVARCHAR (30)   NULL,
    [NAME_PREFIX]            NVARCHAR (5)    NULL,
    [NAME_SUFFIX]            NVARCHAR (15)   NULL,
    [EMP_ID]                 NVARCHAR (11)   NOT NULL,
    [PPS_ID]                 NVARCHAR (254)  NULL,
    [BIRTHDATE]              DATETIME2 (7)   NULL,
    [EMP_HIGH_EDU_LVL_CD]    NVARCHAR (2)    NULL,
    [EMP_HIGH_EDU_LVL_DESC]  NVARCHAR (30)   NULL,
    [HIRE_DT]                DATETIME2 (7)   NULL,
    [EMP_ORIG_HIRE_DT]       DATETIME2 (7)   NULL,
    [EMP_WRK_PH_NUM]         NVARCHAR (24)   NULL,
    [EMP_SPOUSE_FULL_NM]     NVARCHAR (50)   NULL,
    [RPTS_TO_POSN_NBR_COUNT] NUMERIC (38)    NULL,
    [EMP_RCD]                NUMERIC (38)    NOT NULL,
    [EFF_DT]                 DATETIME2 (7)   NOT NULL,
    [EFF_SEQ]                NUMERIC (38)    NOT NULL,
    [JOBCODE]                NVARCHAR (6)    NOT NULL,
    [JOBCODE_DESC]           NVARCHAR (30)   NOT NULL,
    [PER_ORG]                NVARCHAR (3)    NOT NULL,
    [JOB_FUNCTION]           NVARCHAR (3)    NOT NULL,
    [JOB_FUNCTION_DESC]      NVARCHAR (30)   NULL,
    [UNION_CD]               NVARCHAR (3)    NOT NULL,
    [POSN_NBR]               NVARCHAR (8)    NOT NULL,
    [RPTS_TO_POSN_NBR]       NVARCHAR (8)    NOT NULL,
    [SAL_ADMIN_PLAN]         NVARCHAR (4)    NOT NULL,
    [GRADE]                  NVARCHAR (3)    NOT NULL,
    [STEP]                   NUMERIC (38)    NOT NULL,
    [EARNS_DIST_TYPE]        NVARCHAR (1)    NOT NULL,
    [STD_HOURS]              NUMERIC (6, 2)  NOT NULL,
    [STD_HRS_FREQUENCY]      NVARCHAR (5)    NOT NULL,
    [FTE]                    NUMERIC (7, 6)  NOT NULL,
    [JOB_F_FTE_PCT]          NUMERIC (7, 6)  NULL,
    [COMP_FREQUENCY]         NVARCHAR (5)    NOT NULL,
    [COMPRATE]               NUMERIC (18, 6) NULL,
    [ANNL_RATE]              NUMERIC (18, 3) NULL,
    [CALC_ANNUAL_RATE]       NUMERIC (18, 3) NULL,
    [EMP_STAT]               NVARCHAR (1)    NOT NULL,
    [EMPL_STAT_DESC]         NVARCHAR (10)   NOT NULL,
    [HR_STAT]                NVARCHAR (1)    NOT NULL,
    [HR_STAT_DESC]           NVARCHAR (10)   NOT NULL,
    [LEAVE_SERVICE_CREDIT]   NUMERIC (14, 2) NULL,
    [WOS_FLAG]               NVARCHAR (1)    NULL,
    [WOS_FUTURE_FLAG]        NVARCHAR (1)    NULL,
    [JOB_IND]                NVARCHAR (1)    NOT NULL,
    [CALC_JOB_IND]           NVARCHAR (1)    NULL,
    [EMP_CLASS]              NVARCHAR (3)    NOT NULL,
    [EMP_CLASS_DESC]         NVARCHAR (10)   NULL,
    [CLASS_CD]               NVARCHAR (1)    NOT NULL,
    [CLASS_CD_DESC]          NVARCHAR (10)   NOT NULL,
    [END_DT]                 DATETIME2 (7)   NULL,
    [AUTO_END]               NVARCHAR (1)    NOT NULL,
    [JOB_DEPT]               NVARCHAR (10)   NOT NULL,
    [DEPT_NAME]              NVARCHAR (40)   NULL,
    [SCH/DIV]                NVARCHAR (6)    NOT NULL,
    [SCH/DIV_DESC]           NVARCHAR (40)   NOT NULL,
    [PAY_GRP]                NVARCHAR (3)    NOT NULL,
    [SUPERVISOR]             NVARCHAR (1)    NULL,
    [REL]                    NVARCHAR (3)    NULL,
    [REL_DESC]               NVARCHAR (30)   NULL,
    [EMAIL]                  NVARCHAR (70)   NOT NULL,
    [UCD_LOGIN_ID]           VARCHAR (100)   NULL,
    [CTO]                    NVARCHAR (3)    NOT NULL,
    [CTO_DESC]               NVARCHAR (50)   NOT NULL,
    [ACAD_FLG]               NVARCHAR (1)    NULL,
    [MSP_FLG]                NVARCHAR (1)    NULL,
    [SSP_FLG]                NVARCHAR (1)    NULL,
    [SUPVR_FLG]              NVARCHAR (1)    NULL,
    [MGR_FLG]                NVARCHAR (1)    NULL,
    [STDT_FLG]               NVARCHAR (1)    NULL,
    [FACULTY_FLG]            NVARCHAR (1)    NULL,
    CONSTRAINT [PK_UCPath_PersonJob] PRIMARY KEY CLUSTERED ([EMP_ID] ASC, [EMP_RCD] ASC, [EFF_DT] ASC, [EFF_SEQ] ASC)
);


GO
CREATE NONCLUSTERED INDEX [UCPath_PersonJob_SchDiv_NCLINDX]
    ON [dbo].[UCPath_PersonJob]([SCH/DIV] ASC);


GO
ALTER INDEX [UCPath_PersonJob_SchDiv_NCLINDX]
    ON [dbo].[UCPath_PersonJob] DISABLE;


GO
CREATE NONCLUSTERED INDEX [UCPath_PersonJob_PPS_ID_NCLINDX]
    ON [dbo].[UCPath_PersonJob]([PPS_ID] ASC);


GO
ALTER INDEX [UCPath_PersonJob_PPS_ID_NCLINDX]
    ON [dbo].[UCPath_PersonJob] DISABLE;


GO
CREATE NONCLUSTERED INDEX [UCPath_PersonJob_Name_NCLINDX]
    ON [dbo].[UCPath_PersonJob]([NAME] ASC);


GO
ALTER INDEX [UCPath_PersonJob_Name_NCLINDX]
    ON [dbo].[UCPath_PersonJob] DISABLE;


GO
CREATE NONCLUSTERED INDEX [UCPath_PersonJob_Job_Ind_NCLINDX]
    ON [dbo].[UCPath_PersonJob]([JOB_IND] ASC);


GO
ALTER INDEX [UCPath_PersonJob_Job_Ind_NCLINDX]
    ON [dbo].[UCPath_PersonJob] DISABLE;


GO
CREATE NONCLUSTERED INDEX [UCPath_PersonJob_EMP_ID_NCLINDX]
    ON [dbo].[UCPath_PersonJob]([EMP_ID] ASC);


GO
ALTER INDEX [UCPath_PersonJob_EMP_ID_NCLINDX]
    ON [dbo].[UCPath_PersonJob] DISABLE;


GO
CREATE NONCLUSTERED INDEX [UCPath_PersonJob_EFF_DT_NCLINDX]
    ON [dbo].[UCPath_PersonJob]([EFF_DT] DESC);


GO
ALTER INDEX [UCPath_PersonJob_EFF_DT_NCLINDX]
    ON [dbo].[UCPath_PersonJob] DISABLE;

