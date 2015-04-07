CREATE TABLE [dbo].[ProjectsRaw] (
    [Id]           INT            IDENTITY (100, 1) NOT NULL,
    [Accession]    NVARCHAR (255) NULL,
    [Project]      NVARCHAR (255) NULL,
    [Station]      NVARCHAR (255) NULL,
    [Title]        NVARCHAR (255) NULL,
    [Inv1]         NVARCHAR (255) NULL,
    [inv2]         NVARCHAR (255) NULL,
    [inv3]         NVARCHAR (255) NULL,
    [inv4]         NVARCHAR (255) NULL,
    [inv5]         NVARCHAR (255) NULL,
    [inv6]         NVARCHAR (255) NULL,
    [Regional]     NVARCHAR (255) NULL,
    [FundType]     NVARCHAR (255) NULL,
    [dept]         NVARCHAR (255) NULL,
    [DeptName]     VARCHAR (1024) NULL,
    [Status]       NVARCHAR (255) NULL,
    [ProgressTerm] NVARCHAR (255) NULL,
    [ProjType]     NVARCHAR (255) NULL,
    [TermDate]     DATETIME       NULL,
    [BeginDate]    DATETIME       NULL,
    [Field2]       VARCHAR (255)  NULL,
    [CrisDate]     DATETIME       NULL,
    [ChangeDate]   DATETIME       NULL,
    [CoopDepts]    VARCHAR (50)   NULL
);



