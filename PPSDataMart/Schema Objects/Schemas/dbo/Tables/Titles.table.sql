CREATE TABLE [dbo].[Titles] (
    [TitleCode]                 NVARCHAR (10)  NOT NULL,
    [Name]                      NVARCHAR (150) NULL,
    [AbbreviatedName]           NVARCHAR (30)  NOT NULL,
    [PersonnelProgramCode]      NVARCHAR (1)   NULL,
    [UnitCode]                  NVARCHAR (3)   NULL,
    [TitleGroup]                NVARCHAR (4)   NULL,
    [TitleGroupDescription]     VARCHAR (50)   NULL,
    [OvertimeExemptionCode]     NVARCHAR (1)   NOT NULL,
    [CTOOccupationSubgroupCode] NVARCHAR (3)   NULL,
    [FederalOccupationCode]     VARCHAR (1)    NULL,
    [FOCSubcategoryCode]        VARCHAR (2)    NULL,
    [LinkTitleGroupCode]        VARCHAR (3)    NULL,
    [JobFamily]                 NVARCHAR (6)   NOT NULL,
    [JobFamilyDescription]      NVARCHAR (30)  NULL,
    [EE06CategoryCode]          NVARCHAR (1)   NULL,
    [StaffType]                 CHAR (2)       NULL,
    [JobFunction]               NVARCHAR (3)   NOT NULL,
    [JobFunctionDescription]    NVARCHAR (30)  NULL,
    [UsOccCode]                 NVARCHAR (4)   NOT NULL,
    [UsOccCodeDescription]      NVARCHAR (50)  NULL,
    [UsSocCode]                 NVARCHAR (10)  NOT NULL,
    [UsSocCodeDescription]      NVARCHAR (50)  NULL,
    [EstabID]                   NVARCHAR (12)  NULL,
    [EffectiveDate]             DATETIME2 (7)  NOT NULL,
    [UpdateTimestamp]           DATETIME2 (7)  NULL,
    [IsNewInUCP]                BIT            NOT NULL,
    CONSTRAINT [PK_Titles] PRIMARY KEY CLUSTERED ([TitleCode] ASC)
);



