CREATE TABLE [dbo].[Departments] (
    [HomeDeptNo]      CHAR (6)     NOT NULL,
    [Name]            VARCHAR (50) NULL,
    [Abbreviation]    VARCHAR (50) NULL,
    [SchoolCode]      VARCHAR (2)  NULL,
    [AdminClusterNo]  VARCHAR (6)  NULL,
    [MailCode]        VARCHAR (5)  NULL,
    [HomeOrgUnitCode] VARCHAR (4)  NULL,
    [IsAdminCluster]  BIT          NULL,
    [LastActionDate]  DATETIME     NULL
);

