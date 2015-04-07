CREATE TABLE [dbo].[2012_ReportingChecklist_temp] (
    [Accession]            NVARCHAR (255) NULL,
    [Project]              NVARCHAR (255) NULL,
    [Title]                NVARCHAR (255) NULL,
    [BeginDate]            DATETIME       NULL,
    [TermDate]             DATETIME       NULL,
    [ProjTypeCd]           NVARCHAR (255) NULL,
    [RegionalProjNum]      NVARCHAR (255) NULL,
    [CRIS_DeptID]          NVARCHAR (255) NULL,
    [CoopDepts]            VARCHAR (50)   NULL,
    [StatusCd]             NVARCHAR (255) NULL,
    [Inv1]                 NVARCHAR (255) NULL,
    [inv2]                 NVARCHAR (255) NULL,
    [inv3]                 NVARCHAR (255) NULL,
    [inv4]                 NVARCHAR (255) NULL,
    [inv5]                 NVARCHAR (255) NULL,
    [inv6]                 NVARCHAR (255) NULL,
    [idProject]            INT            IDENTITY (100, 1) NOT NULL,
    [InReportingChecklist] BIT            NULL
);

