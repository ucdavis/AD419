CREATE TABLE [dbo].[Project] (
    [Accession]           VARCHAR (7)   NULL,
    [Project]             VARCHAR (24)  NULL,
    [IsInterdepartmental] BIT           NULL,
    [isValid]             BIT           NULL,
    [BeginDate]           DATETIME2 (7) NULL,
    [TermDate]            DATETIME2 (7) NULL,
    [ProjTypeCd]          INT           NULL,
    [RegionalProjNum]     INT           NULL,
    [OrgR]                VARCHAR (4)   NULL,
    [CRIS_DeptID]         VARCHAR (4)   NULL,
    [CSREES_ContractNo]   VARCHAR (20)  NULL,
    [StatusCd]            VARCHAR (1)   NULL,
    [Title]               VARCHAR (512) NULL,
    [UpdateDate]          DATETIME2 (7) NULL,
    [inv1]                VARCHAR (100) NULL,
    [inv2]                VARCHAR (100) NULL,
    [Inv3]                VARCHAR (100) NULL,
    [inv4]                VARCHAR (100) NULL,
    [inv5]                VARCHAR (100) NULL,
    [inv6]                VARCHAR (100) NULL,
    [inv7]                VARCHAR (100) NULL,
    [Is204]               BIT           NULL,
    [idProject]           INT           NOT NULL
);


GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20160813-191846]
    ON [dbo].[Project]([isValid] ASC, [OrgR] ASC, [StatusCd] ASC);

