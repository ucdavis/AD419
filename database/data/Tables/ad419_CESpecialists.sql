CREATE TABLE [data].[ad419_CESpecialists]
(
    [DeptCode] NVARCHAR(6) NULL,
    [DeptName] NVARCHAR(200) NULL,
    [Pi] NVARCHAR(200) NULL,
    [DeptLevelOrg] NVARCHAR(50) NOT NULL,
    [EmployeeId] NVARCHAR(8) NULL,
    [ProjectAccessionNum] NVARCHAR(7) NOT NULL,
    [ProjectNumber] NVARCHAR(20) NULL,
    [PercentCeEffort] DECIMAL(9, 6) NOT NULL,
    [FullAnnualPayRate] DECIMAL(19, 4) NOT NULL,
    [TitleCode] NVARCHAR(10) NULL,
    [FTE] DECIMAL(9, 6) NOT NULL,
    [Entity] NVARCHAR(10) NULL,
    [Exp SFN] NVARCHAR(10) NOT NULL,
    [FTE SFN] NVARCHAR(10) NOT NULL,
    CONSTRAINT [PK_ad419_CESpecialists] PRIMARY KEY CLUSTERED ([ProjectAccessionNum])
);
