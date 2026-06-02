CREATE TABLE [data].[ActiveProjects]
(
    [ProjectNumber] NVARCHAR(50) NULL,
    [AccessionNumber] NVARCHAR(50) NULL,
    [UcpEmployeeId] NVARCHAR(50) NULL,
    [UcPathName] NVARCHAR(200) NULL,
    [Is204] BIT NULL,
    [ExcludeFromUi] BIT NULL,
    [Notes] NVARCHAR(MAX) NULL,
    [ProjectDirector] NVARCHAR(200) NULL,
    [PdEmailAddress] NVARCHAR(320) NULL
);
