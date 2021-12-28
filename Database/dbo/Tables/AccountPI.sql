CREATE TABLE [dbo].[AccountPI] (
    [PI_Name]                 VARCHAR (100) NULL,
    [LastName]                VARCHAR (50)  NULL,
    [FirstMiddle]             VARCHAR (50)  NULL,
    [FirstName]               VARCHAR (50)  NULL,
    [MiddleName]              VARCHAR (25)  NULL,
    [EmployeeID]              VARCHAR (10)  NULL,
    [PPS_EmployeeID]          VARCHAR (10)  NULL,
    [PrincipalInvestigatorID] VARCHAR (10)  NULL,
    [IsExistingRecord]        BIT           NULL,
    [LastUpdateDate]          DATETIME2 (7) NULL
);

