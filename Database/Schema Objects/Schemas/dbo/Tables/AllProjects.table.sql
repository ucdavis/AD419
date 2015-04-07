﻿CREATE TABLE [dbo].[AllProjects] (
    [Accession]             CHAR (7)      NOT NULL,
    [Project]               VARCHAR (24)  NOT NULL,
    [isInterdepartmental]   TINYINT       NULL,
    [isValid]               TINYINT       NULL,
    [BeginDate]             DATETIME2 (7) NULL,
    [TermDate]              DATETIME2 (7) NULL,
    [ProjTypeCd]            CHAR (1)      NULL,
    [RegionalProjNum]       VARCHAR (9)   NULL,
    [CRIS_DeptID]           CHAR (4)      NULL,
    [CoopDepts]             VARCHAR (50)  NULL,
    [CSREES_ContractNo]     VARCHAR (20)  NULL,
    [StatusCd]              CHAR (1)      NULL,
    [Title]                 VARCHAR (200) NULL,
    [UpdateDate]            DATETIME2 (7) NULL,
    [inv1]                  VARCHAR (30)  NULL,
    [inv2]                  VARCHAR (30)  NULL,
    [inv3]                  VARCHAR (30)  NULL,
    [inv4]                  VARCHAR (30)  NULL,
    [inv5]                  VARCHAR (30)  NULL,
    [inv6]                  VARCHAR (30)  NULL,
    [idProject]             INT           IDENTITY (1, 1) NOT NULL,
    [IsCurrentAD419Project] BIT           NULL
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'CRIS-assigned project ID', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'Accession';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Station-assigned project ID', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'Project';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'was named Regional', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'RegionalProjNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'CRIS Dept Cd (4 digit #).  WARNING: inconsistent correspondence with UCD  Org', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'CRIS_DeptID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'CSREES contract no (was named FundType)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'CSREES_ContractNo';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Investigator (PI Name)  (should normalize this and other INVx columns)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'inv1';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'autogenerated unique Project ID (identity column)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AllProjects', @level2type = N'COLUMN', @level2name = N'idProject';

