CREATE TABLE [dbo].[Titles] (
    [TitleCode]                 CHAR (4)      NOT NULL,
    [Name]                      VARCHAR (150) NULL,
    [AbbreviatedName]           VARCHAR (30)  NULL,
    [PersonnelProgramCode]      CHAR (1)      NULL,
    [UnitCode]                  VARCHAR (2)   NULL,
    [TitleGroup]                VARCHAR (3)   NULL,
    [OvertimeExemptionCode]     CHAR (1)      NULL,
    [CTOOccupationSubgroupCode] VARCHAR (3)   NULL,
    [FederalOccupationCode]     VARCHAR (1)   NULL,
    [FOCSubcategoryCode]        VARCHAR (2)   NULL,
    [LinkTitleGroupCode]        VARCHAR (3)   NULL,
    [EE06CategoryCode]          VARCHAR (1)   NULL,
    [StaffType]                 CHAR (2)      NULL,
    [EffectiveDate]             DATETIME      NULL,
    [UpdateTimestamp]           DATETIME      NULL
);

