CREATE TABLE [dbo].[FieldStationExpensesImport] (
    [Project ID]                      NVARCHAR (255) NULL,
    [Field Station Charge (Line 22F)] MONEY          NULL,
    [Investigator]                    NVARCHAR (255) NULL,
    [Project_Type]                    NVARCHAR (255) NULL,
    [Accession_#]                     NVARCHAR (255) NULL,
    [Start Date]                      DATETIME       NULL,
    [End Date]                        DATETIME       NULL,
    [Project_Status]                  NVARCHAR (255) NULL,
    [Dept_Code]                       NVARCHAR (255) NULL,
    [Department]                      NVARCHAR (255) NULL,
    [1st Coop Dept#]                  NVARCHAR (255) NULL,
    [2nd Coop# Dept#]                 NVARCHAR (255) NULL,
    [Notes]                           NVARCHAR (255) NULL
);

