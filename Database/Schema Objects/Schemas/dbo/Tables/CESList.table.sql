CREATE TABLE [dbo].[CESList] (
    [EID]                 VARCHAR (9)   NULL,
    [Title_Code]          VARCHAR (4)   NULL,
    [AccountPIName]       NVARCHAR (50) NULL,
    [CESEmployeeFullName] NVARCHAR (50) NULL,
    [IfInclude]           TINYINT       NULL,
    [idCE]                INT           IDENTITY (1, 1) NOT NULL
);

