CREATE TABLE [dbo].[MCCA_AllNonExcludedEmployees] (
    [Id]       INT            IDENTITY (1, 1) NOT NULL,
    [EMP_ID]   NVARCHAR (11)  NOT NULL,
    [Name]     NVARCHAR (50)  NOT NULL,
    [JOB_DEPT] NVARCHAR (10)  NOT NULL,
    [JOBCODE]  NVARCHAR (6)   NOT NULL,
    [FTE]      NUMERIC (7, 6) NOT NULL,
    [EFF_DT]   DATETIME2 (7)  NOT NULL,
    [EMP_RCD]  NUMERIC (38)   NOT NULL,
    [EFF_SEQ]  NUMERIC (38)   NOT NULL,
    [EMP_STAT] NVARCHAR (1)   NOT NULL
);

